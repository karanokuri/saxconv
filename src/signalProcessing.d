module signalprocessing;

import std.traits;
import std.range;

/**
 * 与えられたレンジの自己相関を計算する
 *
 * 自己相関の式: r(lag) = sum[range(i)range(i+lag)]
 *
 * Params:
 *    range = 信号となるレンジ
 *    len   = 相関をとる範囲
 *    lag   = 遅延させるサンプル数
 *
 * Returns:
 *    自己相関関数 r(lag) の値
 */
auto autoCorrelation(R)(R range, size_t len, size_t lag)
  if (isRandomAccessRange!R && hasLength!R)
{
  typeof(range[0]) ret = 0;
  for(int i = 0; i < len; i++)
    ret += range[i] * range[i+lag];

  return ret;
}

/**
 * 以下の式で与えられる自己相関関数の値が最大となる lag を求める
 * r(lag) = sum[range(i)range(i+lag)]
 * lagMin <= lag <= lagMax
 *
 * Params:
 *    range  = 信号となるレンジ
 *    len    = 相関をとる範囲
 *    lagMin = 遅延させるサンプル数 lag の最小値
 *    lagMax = 遅延させるサンプル数 lag の最大値
 */
size_t peakOfAutoCorrelation(R)(R range, size_t len, size_t lagMin, size_t lagMax)
  if (isRandomAccessRange!R && hasLength!R)
{
  auto peak = lagMin;
  typeof(range[0]) max = 0;
  for(int lag = lagMin; lag <= lagMax; lag++)
  {
    auto val = range.autoCorrelation(len, lag);
    if(max < val)
    {
      max = val;
      peak = lag;
    }
  }
  return peak;
}

/// シンク関数
T sinc(T)(T x)
{
  import std.math : sin;

	return (x == 0.0) ? (1.0) : (sin(x)/x);
}

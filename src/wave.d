module wave;

import std.file;
import std.math;
import std.exception;

class Wave
{
private:
	double[] ldata;
	double[] rdata;

	union st_fmt_chunk
	{
		struct
		{
			char[4] id = "fmt ";
			int size = 16;
			short format = 1;
			short channel = 1;
			int samples_per_sec;
			int bytes_per_sec;
			ushort block_size = 1;
			ushort bits_per_sample = 8;
		}
		byte[24] bytes;
	}
	st_fmt_chunk fmt;

	R pitchShift(R, F)(R range, F pitch, void delegate(double) dg = null)
    if (isRandomAccessRange!R && hasLength!R && isFloatingPoint!F)
  in
  {
    assert(pitch > 0.0);
  }
  body
	{
		enum SINC_LEN = 24;

    import std.conv : to;
    import std.algorithm : fill;

		if (pitch == 1.0)
			return range;

		auto data = timeStretch(range, 1/pitch, dg);

    R ret;
		ret.length = range.length;
		ret.fill(0);

    // リサンプリング
    for (size_t i = 0; i < ret.length; i++)
		{
			auto t = pitch * i;
			auto offset = t.to!int;
			for (size_t j = offset - SINC_LEN/2; j <= offset + SINC_LEN/2; j++)
				if (0 <= j && j < data.length)
					ret[i] += data[j] * sinc(PI * (t - j));
		}

		return ret;
	}

  R timeStretch(R, F)(R range, F rate, void delegate(double) dg = null)
    if (isRandomAccessRange!R && hasLength!R && isFloatingPoint!F)
  {
    import std.conv : to;
    import std.algorithm : fill;

    if (rate == 1.0)
      return range;

    R ret;
    ret.length = cast(size_t)(range.length / rate) + 1;
		ret.fill(0);

    // 自己相関をとるサンプル数
    int corrLen = (fmt.samples_per_sec * 0.01).to!int;

    // 相関関数の最大値を探索する範囲
    int pmin    = (fmt.samples_per_sec * 0.005).to!int;
    int pmax    = (fmt.samples_per_sec * 0.02).to!int;

    int offset0, offset1;
    if (rate > 1.0)
    {
      while (offset0 + pmax*2 < range.length && offset1 + pmax*2 < ret.length)
      {
        if(dg)
          dg(offset0.to!double / range.length);

        // 相関関数の値が最も大きい周期を基本周期とみなす
        auto period = peakOfAutoCorrelation(range[offset0..$], corrLen, pmin, pmax);

        for (int i = 0; i < period; i++)
        {
          // オーバーラップアド
          //ret[offset1+i] = range[offset0+i]*(p - i)/p; // 単調減少の重みづけ
          //ret[offset1+i] += range[offset0+p+i]*i/p;    // 単調増加の重みづけ
          // 上の二つの式を整理したもの
          // range[offset0 + i] = a , range[offset0 + p + i] = b とおくと、
          // ret[offset1 + i] に代入される値は以下のように表すことができる
          //   a(p - i)/p + bi/p = {a(p - i) + bi}/p
          // = (ap - ai + bi)/p  = {ap + (-a + b)i}/p
          // = a + (b - a)i/p
          ret[offset1+i] = (range[offset0+i+period] - range[offset0+i])*i/period
                            + range[offset0+i];
        }

        // offset0, offset1 の更新
        auto q = (period/(rate - 1.0) + 0.5).to!int;
        for (int i = period; i < q; i++)
        {
          if (offset0+period+i >= range.length)
            break;
          ret[offset1+i] = range[offset0+period+i];
        }
        offset0 += period + q;
        offset1 += q;
      }
    }
    else	// rate < 1.0
    {
      while (offset0 + pmax * 2 < range.length)
      {
        if(dg)
          dg(offset0.to!double / range.length);

        // 相関関数の値が最も大きい周期を基本周期とみなす
        auto period = peakOfAutoCorrelation(range[offset0..$], corrLen, pmin, pmax);

        for (size_t i = 0; i < period; i++)
        {
          ret[offset1 + i] = range[offset0 + i];

          // オーバーラップアド
          //ret[offset1+p+i] = range[offset0+p+i]*(p - i)/p; // 単調減少の重みづけ
          //ret[offset1+p+i] += range[offset0+i]*i/p;        // 単調増加の重みづけ
          // rate > 1 のときと同様にして上の式を整理したもの
          ret[offset1+period+i] = (range[offset0+i] - range[offset0+i+period])*i/period
                                + range[offset0+i+period];
        }

        // offset0, offset1 の更新
        auto q = (period*rate/(1.0 - rate) + 0.5).to!int;
        for (size_t i = period; i < q; i++)
        {
          if (offset0 + i >= range.length)
            break;
          ret[offset1+period+i] = range[offset0+i];
        }
        offset0 += q;
        offset1 += period + q;
      }
    }

    return ret;
  }

	// ------------------------------------------------------------------------------------------------------------------
public:

	this(string filename)
	{
		this.read(filename);
	}

	// ------------------------------------------------------------------------------------------------------------------
	void read(string filename)
	{
		byte[] read_data;
		size_t offset;
		byte[4] chunk_id;
		double[] data;

		union _chunk_size
		{
			int i;
			byte[4] bytes;
		}
		_chunk_size chunk_size;

		union _two_bytes
		{
			short s;
			byte[2] bytes;
		}
		_two_bytes two_bytes;

		read_data = cast(byte[])std.file.read(filename);

		enforce(read_data[0..4]  == "RIFF", "riff形式ではありません");
		enforce(read_data[8..12] == "WAVE", "waveファイルではありません");

		fmt.bytes[] = read_data[12..36];
		enforce(fmt.id == "fmt ", "fmtチャンクが存在しません");

		offset = 12 + 8 + fmt.size;
		do	// dataチャンクを見つけ、チャンクの大きさを読む
		{
			offset += chunk_size.i;
			chunk_id[] = read_data[offset .. (offset + 4)];	offset += 4;
			chunk_size.bytes[] = read_data[offset .. (offset + 4)];	offset += 4;
		}
		while (chunk_id != "data");

		if (fmt.bits_per_sample == 16)
		{
			data.length = chunk_size.i / 2;
			for(int i = 0; i < data.length; i++)
			{
				two_bytes.bytes[] = read_data[offset .. (offset + 2)];	offset += 2;
				data[i] = two_bytes.s / 32768.0;
			}
		}
		else if (fmt.bits_per_sample ==  8)
		{
			data.length = chunk_size.i;
			foreach(i, d; read_data[offset .. (offset + chunk_size.i)])
				data[i] = (d - 128.0) / 128.0;	// 音データを-1以上1未満の範囲に正規化する
		}
		else
			throw new Exception("サンプルあたりのbit数が不正です");

		if (fmt.channel == 2)
		{
			ldata.length = data.length / 2;
			rdata.length = data.length / 2;
			for (int i = 0; i < data.length; i++)
				(i % 2 == 0 ? ldata[i/2] : rdata[i/2]) = data[i];
		}
		else if(fmt.channel == 1)
			ldata = rdata = data;
		else
			throw new Exception("チャンネル数が不正です");
	}

	void write(string filename)
	{
		enforce(fmt.channel == 1 || fmt.channel == 2, "チャンネル数が不正です");
		enforce(fmt.bits_per_sample == 8 || fmt.bits_per_sample == 16, "サンプルあたりのbit数が不正です");

		union _write_data
		{
			struct
			{
				char[4] riff_chunk_ID;
				uint riff_chunk_size;
				char[4] riff_form_type;
				byte[24] fmt_chunk;
				char[4] data_chunk_ID;
				uint data_chunk_size;
			}
			byte[8 + 36] b;
			short[44 / 2] s;
		}
		_write_data write_data;
		auto write_fmt = fmt;
		int data_len;
		double[] data;
		double d;

		write_fmt.size = 16;
		data_len = ldata.length * (fmt.bits_per_sample / 8) * fmt.channel;

		with (write_data)
		{
			riff_chunk_ID = "RIFF";
			riff_chunk_size = 36 + data_len;
			riff_form_type = "WAVE";
			fmt_chunk = write_fmt.bytes;
			data_chunk_ID = "data";
			data_chunk_size = data_len;
		}

		if (fmt.channel == 2)
		{
			data.length = ldata.length * 2;
			for (int i = 0; i < data.length; i++)
				data[i] = (i % 2 == 0 ? ldata[i/2] : rdata[i/2]);
		}
		else if (fmt.channel == 1)
			data = ldata;

		if (fmt.bits_per_sample == 16)
		{
			short[] s = new short[data.length];
			for (int i = 0; i < data.length; i++)
			{
				d = (data[i] + 1.0) / 2.0 * 65536.0;
				if (d > 65535.0)
					d = 65535.0;
				else if (d < 0.0)
					d = 0.0;
				s[i] = cast(short)(d - 32768); /* 四捨五入とオフセットの調節 */
			}
			std.file.write(filename, write_data.s ~ s);
		}
		else if (fmt.bits_per_sample == 8)
		{
			byte[] b = new byte[data.length];
			for (int i = 0; i < data.length; i++)
			{
				d = (data[i] + 1.0) / 2.0 * 256.0;
				if (d > 255.0)
					d = 255.0;
				else if (d < 0.0)
					d = 0.0;
				b[i] = cast(byte)(d + 0.5); /* 四捨五入 */
			}
			std.file.write(filename, write_data.b ~ b);
		}

		delete data;
	}

	// ------------------------------------------------------------------------------------------------------------------
	void timeStretch(double rate, void delegate(double) dg = null)
	{
		if (rate == 1.0)
			return;

		if (fmt.channel == 2)
		{
			timeStretch(ldata, ldata.dup, rate, (dg != null) ? delegate(double p){ dg(p / 2);       } : null);
			timeStretch(rdata, rdata.dup, rate, (dg != null) ? delegate(double p){ dg(p / 2 + 0.5); } : null);
		}
		else
			timeStretch(ldata, ldata.dup, rate, dg);
	}

	// ------------------------------------------------------------------------------------------------------------------
	void pitchShift(double pitch, void delegate(double) dg = null)
	{
		enforce(pitch > 0);

		if (pitch == 1.0)
			return;

		if (fmt.channel == 2)
		{
			pitchShift(ldata, ldata.dup, pitch, (dg != null) ? delegate(double p){ dg(p / 2);       } : null);
			pitchShift(rdata, rdata.dup, pitch, (dg != null) ? delegate(double p){ dg(p / 2 + 0.5); } : null);
		}
		else
			pitchShift(ldata, ldata.dup, pitch, dg);
	}

	void semitoneShift(int semitone, void delegate(double) dg = null)
	{
		if (semitone == 0)
			return;

		pitchShift( pow(2, semitone / 12.0) , dg);
	}
}

private real sinc(real x)
{
	return (x == 0.0) ? (1.0) : (sin(x)/x);
}

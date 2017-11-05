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

	// ------------------------------------------------------------------------------------------------------------------
	int autoCorrelation(in double[] range, int N, int pmin)
	{
		double r;
		double max_of_r = 0.0;
		int p = pmin;
		int pmax = range.length - N;

		for (int m = pmin; m <= pmax; m++)
		{
			r = 0.0;
			for (int n = 0; n < N; n++)
				r += range[n] * range[m + n]; /* 相関関数 */

			if (r > max_of_r)
			{
				max_of_r = r; /* 相関関数のピーク */
				p = m; /* 音データの基本周期 */
			}
		}

		return p;
	}

	double[] pitchShift(out double[] out_data, in double[] in_data, double pitch, void delegate(double) progress_dg = null)
	{
		enforce(pitch > 0.0);

		if (pitch == 1.0)
		{
			out_data = in_data.dup;
			return out_data;
		}

		const J = 24;
		int offset, m, n;
		double t;
		double[] data;

		timeStretch(data, in_data, 1/pitch, progress_dg);

		out_data.length = in_data.length;
		out_data[] = 0;
		for (n = 0; n < out_data.length; n++)
		{
			t = pitch * n;
			offset = cast(int)t;
			for (m = offset - J / 2; m <= offset + J / 2; m++)
			{
				if (m >= 0 && m < data.length)
					out_data[n] += data[m] * sinc(PI * (t - m));
			}
		}

		return out_data;
	}

	double[] timeStretch(out double[] out_data, in double[] in_data, double rate, void delegate(double) progress_dg = null)
	{
		//enforce(0.5 <= rate);

		if (rate == 1.0)
		{
			out_data = in_data.dup;
			return out_data;
		}

		int m, n, template_size, pmin, pmax, p, q, offset0, offset1;

		out_data.length = cast(size_t)(in_data.length / rate) + 1;

		template_size = cast(int)(fmt.samples_per_sec * 0.01); /* 10ms */
		pmin = cast(int)(fmt.samples_per_sec * 0.005); /* 5ms */
		pmax = cast(int)(fmt.samples_per_sec * 0.02); /* 20ms */

		offset0 = offset1 = 0;
		if (rate > 1.0)
		{
			while (offset0 + pmax * 2 < in_data.length && offset1 + pmax * 2 < out_data.length)
			{
				if(progress_dg)
					progress_dg( cast(double)offset0 / in_data.length );

				p = autoCorrelation(in_data[offset0 .. (offset0 + pmax)], template_size, pmin);

				for (n = 0; n < p; n++)
				{
					//out_data[offset1 + n] = in_data[offset0 + n] * (p - n) / p; /* 単調減少の重みづけ */
					//out_data[offset1 + n] += in_data[offset0 + p + n] * n / p; /* 単調増加の重みづけ */
					// = i(p - n)/p + jn/p   = (ip - in)/p + jn/p = ( ip - in + jn )/p
					// = { ip + (j - i)n }/p = i + (j - i)n/p
					out_data[offset1 + n] = (in_data[offset0 + n + p] - in_data[offset0 + n]) * n / p + in_data[offset0 + n];
				}

				q = cast(int)(p / (rate - 1.0) + 0.5);
				for (n = p; n < q; n++)
				{
					if (offset0 + p + n >= in_data.length)
						break;
					out_data[offset1 + n] = in_data[offset0 + p + n];
				}

				offset0 += p + q; /* offset0の更新 */
				offset1 += q; /* offset1の更新 */
			}
		}
		else	// rate < 1.0
		{
			while (offset0 + pmax * 2 < in_data.length)
			{
				if(progress_dg)
					progress_dg( cast(double)(offset0 + pmax) / in_data.length );

				p = autoCorrelation(in_data[offset0 .. (offset0 + pmax)], template_size, pmin);

				for (n = 0; n < p; n++)
					out_data[offset1 + n] = in_data[offset0 + n];
				for (n = 0; n < p; n++)
				{
					//out_data[offset1 + p + n] = in_data[offset0 + p + n] * (p - n) / p; /* 単調減少の重みづけ */
					//out_data[offset1 + p + n] += in_data[offset0 + n] * n / p; /* 単調増加の重みづけ */
					out_data[offset1 + p + n] = (in_data[offset0 + n] - in_data[offset0 + n + p]) * n / p + in_data[offset0 + n + p];
				}

				q = cast(int)(p * rate / (1.0 - rate) + 0.5);
				for (n = p; n < q; n++)
				{
					if (offset0 + n >= in_data.length)
						break;
					out_data[offset1 + p + n] = in_data[offset0 + n];
				}

				offset0 += q; /* offset0の更新 */
				offset1 += p + q; /* offset1の更新 */
			}
		}

		return out_data;
	}

	// ------------------------------------------------------------------------------------------------------------------
public:
	@property
	{
		ref double[] lData() { return ldata; }
		ref double[] rData() { return rdata; }

		size_t length() { return ldata.length; }
		void length(size_t l) { ldata.length = l; rdata.length = l; }

		int samplesPerSec()          { return fmt.samples_per_sec; }
		void samplesPerSec(int i)    { fmt.samples_per_sec = i; }
		ushort bitsPerSample()       { return fmt.bits_per_sample; }
		void bitsPerSample(ushort i) { enforce(i == 8 || i == 16); fmt.bits_per_sample = i; }
	}

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
	void timeStretch(double rate, void delegate(double) progress_dg = null)
	{
		if (rate == 1.0)
			return;

		if (fmt.channel == 2)
		{
			timeStretch(ldata, ldata.dup, rate, (progress_dg != null) ? delegate(double p){ progress_dg(p / 2);       } : null);
			timeStretch(rdata, rdata.dup, rate, (progress_dg != null) ? delegate(double p){ progress_dg(p / 2 + 0.5); } : null);
		}
		else
			timeStretch(ldata, ldata.dup, rate, progress_dg);
	}

	// ------------------------------------------------------------------------------------------------------------------
	void pitchShift(double pitch, void delegate(double) progress_dg = null)
	{
		enforce(pitch > 0);

		if (pitch == 1.0)
			return;

		if (fmt.channel == 2)
		{
			pitchShift(ldata, ldata.dup, pitch, (progress_dg != null) ? delegate(double p){ progress_dg(p / 2);       } : null);
			pitchShift(rdata, rdata.dup, pitch, (progress_dg != null) ? delegate(double p){ progress_dg(p / 2 + 0.5); } : null);
		}
		else
			pitchShift(ldata, ldata.dup, pitch, progress_dg);
	}

	void semitoneShift(int semitone, void delegate(double) progress_dg = null)
	{
		if (semitone == 0)
			return;

		pitchShift( pow(2, semitone / 12.0) , progress_dg);
	}
}

private real sinc(real x)
{
	return (x == 0.0) ? (1.0) : (sin(x)/x);
}

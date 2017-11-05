import dfl.all;
import gui;
import wave;

int main()
{
	//auto wave = new Wave("アルト.wav");

	//wave.timeStretch(2);
	//wave.pitchShift(2);
	//wave.write("conv_アルト.wav");

	//wave.semitoneShift(5);
	//wave.write("alto_to_soprano.wav");
	//wave.semitoneShift(-5);
	//wave.write("soprano_to_alto.wav");

	//wave.read("alto.wav");
	//wave.semitoneShift(-7);
	//wave.write("alto_to_tenor.wav");

	//if(wave.samplesPerSec == 0 || wave.samplesPerSec != 0)
	//	return 0;

	int result = 0;

	try
	{
		// Application initialization code here.

		Application.enableVisualStyles();
		Application.run(new ConvForm);
	}
	catch(DflThrowable o)
	{
		msgBox(o.toString(), "Fatal Error", MsgBoxButtons.OK, MsgBoxIcon.ERROR);

		result = 1;
	}

	return result;
}

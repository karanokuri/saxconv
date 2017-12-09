import dfl.all;
import gui;
import wave;

int main()
{
  int result = 0;

  try
  {
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

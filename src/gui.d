module gui;

import std.stdio;
import std.string;
import std.file, std.path;
import std.exception;
import core.thread;
import dfl.all;
import wave;

const TITLE = "さっくすこんぶ";

class SaxesListBox : ListBox
{
	this()
	{
		items.add("ソプリロ");
		items.add("ソプラニーノ");
		items.add("ソプラノ");
		items.add("アルト");
		items.add("テナー");
		items.add("バリトン");
		items.add("バス");
		items.add("コントラバス");
		items.add("サブコントラバス");
	}
}

class PathControl
{
private:
	class PathLabel: Label
	{
		protected override void onPaint(PaintEventArgs ea)
		{
			scope tfmt = new TextFormat(TextFormatFlags.NO_PREFIX
			| TextFormatFlags.SINGLE_LINE | TextFormatFlags.NO_CLIP);
			tfmt.trimming = TextTrimming.ELLIPSIS_PATH;
			tfmt.alignment = TextAlignment.LEFT | TextAlignment.MIDDLE;

			auto rect = Rect(2, 0, clientSize.width - 4, clientSize.height);

			ea.graphics.drawText(text, font, foreColor, rect, tfmt);

			paint(this, ea);
		}
	}

	void onButtonClick(Object sender, EventArgs ea)
	{
		auto fd = new OpenFileDialog;
		with(fd)
		{
			initialDirectory = getcwd() ~ `\`;
			title            = "ファイルを開く";
			filter           = "Waveファイル (*.wav)|*.wav";
			defaultExt       = "wav";
			validateNames    = true;
		}

		if(fd.showDialog() == DialogResult.OK)
			label.text = _path = fd.fileName;
	}

	string _path;
	PathLabel label;
	Button button;

public:
	@property
	{
		Control parent() { return label.parent; }
		void parent(Control p)
		{
			label.parent = p;
			button.parent = p;
		}

		bool enabled() { return button.enabled; }
		void enabled(bool b) { button.enabled = b; }

		string path() { return _path; }
		void path(string s) { label.text = _path = s; }

		string text() { return label.text; }
		void text(string s) { label.text = s; _path = ""; }

		int width() { return label.width + button.width; }
		void width(int i) { label.width = i - button.width; button.left = label.right; }

		int height() { return label.height; }
		void height(int i) { label.height = i; button.height = i; }

		Point location() { return label.location; }
		void location(Point p) { label.location = p; button.location = p + Size(label.width, 0); }
	}

	this()
	{
		with(label = new PathLabel)
		{
			borderStyle = BorderStyle.FIXED_3D;
		}

		with(button = new Button)
		{
			text = "参照";
			click ~= &onButtonClick;
			left = label.right;
			top = label.top;
			width = 50;
		}
	}
}

class ConvForm : Form
{
private:
	Button convBtn;
	Label pathLabel;
	PathControl pathControl;
	PictureBox arrow, arrow_progress;
	SaxesListBox convFromList, convToList;
	Label convFormLabel, convToLabel;
	Label convFromText, convToText;
	PictureBox convFormIcon, convToIcon;

	double convProgress;
	Thread convThread;
	Wave convWave;

	void controlsInitialize()
	{
		dockPadding.all = 5;
		text = TITLE;
		this.icon = Application.resources.getIcon(101);

		clientSize = dfl.drawing.Size(400, 170);
		location = dfl.drawing.Point(0, 0);
		minimumSize = dfl.drawing.Size(width, height);
		maximumSize = dfl.drawing.Size(width, height);

		with(convBtn = new Button)
		{
			text = "変換";
			click ~= &this.convert;
			parent = this;
		}

		with(pathLabel = new Label)
		{
			text = "ファイル：";
			autoSize = true;
			parent = this;
		}

		with(pathControl = new PathControl)
		{
			text = "変換元のwavファイルを指定してください";
			parent = this;
		}

		with(convFromList = new SaxesListBox)
		{
			height = this.clientSize.height - pathControl.height - 10;
			parent = this;
			selectedValueChanged ~= delegate(Object sender, EventArgs ea)
			{
				convFromText.text = selectedValue.toString();
				convFormIcon.image = Application.resources.getIcon(121 + selectedIndex, false);
			};
		}

		with(convToList = new SaxesListBox)
		{
			height = this.clientSize.height - pathControl.height - 10;
			parent = this;
			selectedValueChanged ~= delegate(Object sender, EventArgs ea)
			{
				convToText.text = selectedValue.toString();
				convToIcon.image = Application.resources.getIcon(121 + selectedIndex, false);
			};
		}

		with(convFromText = new Label)
		{
			textAlign = ContentAlignment.MIDDLE_CENTER;
			borderStyle = BorderStyle.FIXED_SINGLE;
			width = 80;
			height = 21;
			parent = this;
		}

		with(convToText = new Label)
		{
			textAlign = ContentAlignment.MIDDLE_CENTER;
			borderStyle = BorderStyle.FIXED_SINGLE;
			width = 80;
			height = 21;
			parent = this;
		}

		with(convFormLabel = new Label)
		{
			text = "from";
			autoSize = true;
			parent = this;
		}

		with(convToLabel = new Label)
		{
			text = "to";
			autoSize = true;
			parent = this;
		}

		with(convFormIcon = new PictureBox)
		{
			name = "from";
			borderStyle = BorderStyle.FIXED_SINGLE;
			backColor = Color(0xFF, 0xFF, 0xFF);
			parent = this;
		}

		with(convToIcon = new PictureBox)
		{
			name = "to";
			borderStyle = BorderStyle.FIXED_SINGLE;
			backColor = Color(0xFF, 0xFF, 0xFF);
			parent = this;
		}

		with(arrow = new PictureBox)
		{
			name = "arrow";
			parent = this;
			image = Application.resources.getIcon(110, true);
		}

		with(arrow_progress = new PictureBox)
		{
			name = "arrow_progress";
			parent = this;
			image = Application.resources.getIcon(111, true);
			bringToFront();
		}
	}

	void controlsPos()
	{
		convBtn.location = Point(0, 0) + this.clientSize - Size(convBtn.width + 5, convBtn.height + 5);
		pathLabel.location = Point(5, this.clientSize.height - pathLabel.height - 10);
		pathControl.width = convBtn.left - pathLabel.width - 20;
		pathControl.location = Point(pathLabel.right + 5, this.clientSize.height - pathControl.height - 5);

		convFromList.width = this.clientSize.width / 4;
		convFromList.location = Point(5, 5);
		convToList.width = this.clientSize.width / 4;
		convToList.location = Point(this.clientSize.width - convToList.width - 5, 5);

		arrow.bounds = Rect(this.clientSize.width/2-16, this.clientSize.height/4+32, 32, 32);
		arrow_progress.bounds = Rect(arrow.left, arrow.top, cast(int)(convProgress * 32), 32);

		convFromText.location = Point(convFromList.right + 5, arrow.top - 40);
		convToText.location = Point(convToList.left - convToText.width - 5, arrow.top - 40);
		convFormLabel.location = Point(convFromText.left + 5, convFromText.top - convFormLabel.height - 5);
		convToLabel.location = Point(convToText.left + 5, convToText.top - convToLabel.height - 5);
		convFormIcon.bounds = Rect(convFromText.left + 8, convFromText.bottom + 5, 64, 64);
		convToIcon.bounds = Rect(convToText.left + 8, convToText.bottom + 5, 64, 64);

		convFromList.height = this.clientSize.height - pathControl.height - 10;
		convToList.height = this.clientSize.height - pathControl.height - 10;
	}

	void ControlsEnabled(bool b)
	{
		convBtn.enabled = b;
		pathControl.enabled = b;
		convFromList.enabled = b;
		convToList.enabled = b;
	}

	void convert(Object sender, EventArgs ea)
	{
		if(!convFromList.selectedItem || !convToList.selectedItem || pathControl.path == ""
			 || convToList.selectedIndex == convFromList.selectedIndex)
		{
			string errmsg;

			if(!convFromList.selectedItem)
				errmsg ~= "\n\n変換元のサックスが選択されていません";
			if(!convToList.selectedItem)
				errmsg ~= "\n\n変換先のサックスが選択されていません";
			if(convFromList.selectedItem && convToList.selectedItem
				 && convToList.selectedIndex == convFromList.selectedIndex)
				errmsg ~= "\n\n変換元と変換先に同一のサックスが指定されています";
			if(pathControl.path == "")
				errmsg ~= "\n\n変換元のファイルが指定されていません";

			msgBox(errmsg[2..$], TITLE, MsgBoxButtons.OK, MsgBoxIcon.INFORMATION);
			return;
		}

		int semitone;
		SaveFileDialog fd;

		with(fd = new SaveFileDialog)
		{
			initialDirectory = getcwd() ~ `\`;
			title            = "名前を付けて保存";
			fileName         = "conv_" ~ baseName(pathControl.path);
			filter           = "Waveファイル (*.wav)|*.wav";
			defaultExt       = "wav";
			validateNames    = true;
		}

		if(fd.showDialog() != DialogResult.OK)
			return;

		if(convWave)
			delete convWave;
		convWave = new Wave(pathControl.path);

		semitone = (convFromList.selectedIndex / 2) * 12 + (convFromList.selectedIndex % 2) * 5;	// 一度ソプリロの音階にまで上げる
		semitone -= (convToList.selectedIndex / 2) * 12 + (convToList.selectedIndex % 2) * 5;	// 変換先の音階にまで下げる

		void progress_dg(double p)
		{
			convProgress = p;
			this.invoke( { arrow_progress.bounds = Rect(arrow.left, arrow.top, cast(int)(convProgress * 32), 32); } );
		}
		void thread_process()
		{
			ControlsEnabled(false);
			this.text = TITLE ~ " | 変換処理中...";
			convWave.semitoneShift(semitone, &progress_dg);
			this.text = TITLE ~ " | ファイル出力中...";
			convWave.write(fd.fileName);
			this.text = TITLE ~ " | 変換完了";
			msgBox("変換が完了しました", TITLE, MsgBoxButtons.OK, MsgBoxIcon.INFORMATION);
			ControlsEnabled(true);
		}

		convThread = new Thread(&thread_process);
		convThread.start();
	}

	protected override void onResize(EventArgs ea)
	{
		super.onResize(ea);
		controlsPos();
	}

	protected override void onClosing(CancelEventArgs cea)
	{
		if(convThread && convThread.isRunning)
			cea.cancel = true;
		super.onClosing(cea);
	}

	protected override void onClosed(EventArgs ea)
	{
		super.onClosed(ea);
	}

public:
	this()
	{
		controlsInitialize();
		controlsPos();
	}
}

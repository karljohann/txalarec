(
// 0. Settings
// Where the files will be stored and the rec_info file is located ->
// "/path/to/current/session/"
// thisProcess.nowExecutingPath.dirname
//~storage_path = "/Users/karljohann/Downloads/txalaparta_recordings/session2/";

var data=Dictionary.new;
var thispath = thisProcess.nowExecutingPath.dirname;


//~storage_path = "/media/r2d2/data/txala_irss_data/";
~storage_path = "/home/r2d2/Mahaigaina/delete/";

try { ~synths.collect(_.free) }; // free synths in case they are still around
~synths = List.new;

// calibration window with auto load/save prefs
~controls = Dictionary.new;
w = Window(\Session_settings, 300@100).front;
w.view.decorator = FlowLayout(w.view.bounds);
w.view.decorator.gap=2@2;

~controls[\storage_path] = Button(w, 290@20)
.states_([
	["storage_path", Color.white, Color.black]
])
.action_({ arg butt;
	FileDialog({|path|
		path[0].postln;
		~storage_path = path[0];
		data = Dictionary.new;
		data.put(\storage_path, ~storage_path);
		data.put(\threshold, ~controls[\threshold].value);
		data.put(\relaxtime, ~controls[\relaxtime].value);
		data.writeArchive(thispath ++ "/" ++ "prefs.preset");
	}, fileMode:2)
});
w.view.decorator.nextLine;
~controls[\threshold] = EZSlider( w,         // parent
	290@20,    // bounds
	"threshold",  // label
	ControlSpec(0, 1, \lin, 0.01, 0.06),     // controlSpec
	{ arg ez;
		~synths.do{|syn| syn.set(\threshold, ez.value)};
		data = Dictionary.new;
		data.put(\storage_path, ~storage_path);
		data.put(\threshold, ~controls[\threshold].value);
		data.put(\relaxtime, ~controls[\relaxtime].value);
		data.writeArchive(thispath ++ "/" ++ "prefs.preset");
	},
	initVal: 0.06,
	labelWidth: 60;
);
w.view.decorator.nextLine;
~controls[\relaxtime] = EZSlider( w,         // parent
	290@20,    // bounds
	"relax time",  // label
	ControlSpec(0, 1, \lin, 0.01, 0.01),     // controlSpec
	{ arg ez;
		~synths.do{|syn| syn.set(\relaxtime, ez.value)};
		data = Dictionary.new;
		data.put(\storage_path, ~storage_path);
		data.put(\threshold, ~controls[\threshold].value);
		data.put(\relaxtime, ~controls[\relaxtime].value);
		data.writeArchive(thispath ++ "/" ++ "prefs.preset");
	},
	initVal: 0.01,
	labelWidth: 60;
);


// auto read prefs file. create a default one if not there
data = Object.readArchive(thispath ++ "/" ++ "prefs.preset");
if (data.isNil, { //file wasn't there. create a default one
	data=Dictionary.new;
	data[\storage_path]= ~storage_path;
	data[\threshold]=0.06;
	data[\relaxtime]=0.01;
	data.writeArchive(thispath  ++ "/" ++ "prefs.preset");
});
//data.postln;

//restore the values from the prefs
~storage_path = data[\storage_path];
~controls[\threshold].valueAction_( data[\threshold] );
~controls[\relaxtime].valueAction_( data[\relaxtime] );




// 1. Init
// load the settings dictionary (~recInfo)
(~storage_path +/+ "rec_info.scd").load;

if ((~inputDevice.size > 0), {
	Server.default.options.inDevice_(~inputDevice); // set to soundcard if needed
});
Server.default.options.numInputBusChannels_(~numInputChannels);
s = Server.local;
s.meter(8, 8); // opens the meter window
if (not(s.serverRunning), { s.boot }); // start server

thisProcess.platform.recordingsDir = ~storage_path; // recordings will be stored here

// Write recInfo to CSV file for posterity
~writeConfig = {
	var filepath = ~storage_path +/+ "rec_info.csv";
	var csvfile = File(filepath, "w");
	var headers = "";
	var channels = "";

	// gather channel info
	~recInfo.keysValuesDo{ |key, val|
		headers = headers ++ key.asString ++ ",";
		channels = channels ++ val.asString ++ ",";
	};

	headers = headers ++ "storagepath";
	channels = channels ++ ~storage_path;

	csvfile.write( headers );
	csvfile.write( "\n" );
	csvfile.write( channels );
	csvfile.close;
};
~writeConfig.();

// Returns channels for batons and planks
~getChannels = { |type = \baton|
	var toMatch = if (type == \baton, "p[0-9][rl]", "plk[0-9]");
	var channels = [];
	~recInfo.keysValuesDo{ |key, val|
		if (toMatch.matchRegexp(val), {
			var in = key.asString.findRegexp("ch([0-9]+)");
			var ch = in[1][1].asInteger - 1;
			channels = channels.add(ch);
		});
	};
	channels;
};

// Returns channels to record
~getRecChannels = {
	var recChannels = [];
	~recInfo.keysValuesDo{ |key, val|
		if (val != "", {
			var in = key.asString.findRegexp("ch([0-9]+)");
			var ch = in[1][1].asInteger - 1;
			recChannels = recChannels.add(ch);
		});
	};
	recChannels;
};



// 2. Onset detection synth
SynthDef(\detector, { |in=0, threshold=0.06, relaxtime=0.01, blocksize=1024, gain=0|
	var plank_lvl, plank_idx, freq, hasFreq, baton_lvl, onsets, delayedOnsets, fft;
	var sdel = 0.04; // [threeinputs.scd] this is a small delay to skip the first chaotic miliseconds
	var plank_channels = ~getChannels.(\plk);

	var baton = SoundIn.ar(in) * gain;
	var planks = SoundIn.ar(plank_channels) * gain;
	var planklevels = WAmp.kr(planks, sdel);

	var freqs = Array.newClear(plank_channels.size);

	# plank_lvl, plank_idx = ArrayMax.ar(planklevels); // # val, index

	plank_channels.do{ |plk_ch, i|
		freqs[i] = Pitch.kr(SoundIn.ar(plk_ch), ampThreshold:0.02, median:7); // # freq, hasFreq
	};

	baton_lvl = WAmp.kr(baton, 0.1); // Window size should probably be around 50 ms? (0.05)

	fft = FFT(LocalBuf(blocksize), baton, wintype:1);
	onsets = Onsets.kr(fft, threshold, odftype:\power, relaxtime:relaxtime, mingap:4);
	delayedOnsets = DelayN.kr(onsets, maxdelaytime:sdel, delaytime:sdel); // delay onsets to get plank

	SendReply.kr(delayedOnsets, '/input', [
		in,
		baton_lvl,
		plank_idx,
		plank_lvl,
		Sweep.ar,
		planklevels[0],
		planklevels[1],
		planklevels[2],
		freqs[0][0], // FIXME: Not really working
		freqs[1][0], // FIXME: Not really working
		freqs[2][0], // FIXME: Not really working
	]);

}).add;

// 3. OSC server ->
OSCFunc({
	arg msg;

	// calculate timedelta ->
	var clock = msg[7].asFloat;
	var lasttime = if ((t.lasttime == 0), clock, t.lasttime);
	var timedelta = clock - lasttime;
	var args, player;

	t.lasttime = clock;

	// msg.postln;

	args = Dictionary[
		\baton -> msg[3].asInteger,
		\plank -> msg[5].asInteger,
		\baton_lvl -> msg[4].asFloat,
		\plank_lvl -> msg[6].asFloat, // salient plank level
		\timedelta -> timedelta,
		\clock -> clock,
		\pitch -> msg[11],
		\plank_lvl_1 -> msg[8].asFloat,
		\plank_lvl_2 -> msg[9].asFloat,
		\plank_lvl_3 -> msg[10].asFloat,
	];

	t.hit(SystemClock.seconds, args[\baton_lvl], args[\plank], (args[\baton] + 1), args);

}, '/input');


// 4. Main
s.waitForBoot{
	m = {
		// The values that will be saved to CSV file
		var keys = [ // TODO: This has to be the same as dict below, avoid duplication
			\baton,
			\plank,
			\baton_lvl,
			\plank_lvl,
			\timedelta,
			\clock,
			\pitch,
			\plank_lvl_1,
			\plank_lvl_2,
			\plank_lvl_3,
		];

		// get the batons to listen to from recInfo ->
		var batonChannels = ~getChannels.();
		batonChannels.do{ |ch|
			// create onset detection synth for each baton
			~synths.add( Synth(\detector, [\in, ch]) );
		};

		// Init GUI ->
		t = TxalaRecGUI.new;
		t.doTxalaScore();
		t.updateNumPlanks(3);
		t.setFileStoragePath(~storage_path);
		t.setCSVKeys(keys);
		t.setRecChannels(~getRecChannels);
	};
	m.();
}
)

// Stop recording ->
// Server.default.stopRecording; // also stops on cmd-.

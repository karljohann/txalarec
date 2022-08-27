(
// SETTINGS DIALOGUES =>
var data = Dictionary.new;
var thispath = thisProcess.nowExecutingPath.dirname;
var persistControls;
~storage_path = "";
~wait_for_path = CondVar();

// calibration window with auto load/save prefs
~controls = Dictionary.new;
w = Window(\Session_settings, 300@100).front;
w.view.decorator = FlowLayout(w.view.bounds);
w.view.decorator.gap = 2@2;

persistControls = { |storage_path, controls|
	data = Dictionary.new;
	data.put(\storage_path, storage_path);
	data.put(\threshold, controls[\threshold].value);
	data.put(\relaxtime, controls[\relaxtime].value);
	data.put(\gain, controls[\gain].value);
	data.writeArchive(thispath ++ "/" ++ "prefs.preset");
};

~controls[\storage_path] = Button(w, 290@20)
.states_([
	["storage_path", Color.white, Color.black]
])
.action_({ arg butt;
	FileDialog({ |path|
		var old_path = ~storage_path;
		~storage_path = path[0];
		persistControls.(~storage_path, ~controls);
		if (File.exists(~storage_path +/+ "rec_info.scd"), { // continue if file exists (else things will break)
			~wait_for_path.signalOne; // let the process know that the storage path has been set
			// FIXME: We should run main every time path is changed?
			if ((old_path != ~storage_path), { // Only run if path changed
				~main.(~storage_path);
			});
		}, {
			"rec_info.scd does not exists in selected directory".postln;
		});
	},
	fileMode: 2,
	// path: if (~storage_path.notEmpty, ~storage_path, "") // Default? Just use storage_path, no ifs
	// path: ~storage_path
	)
});
w.view.decorator.nextLine;
~controls[\threshold] = EZSlider( w,         // parent
	290@20,    // bounds
	"threshold",  // label
	ControlSpec(0, 1, \lin, 0.01, 0.06),     // controlSpec
	{ arg ez;
		~synths.do{ |syn| syn.set(\threshold, ez.value) };
		persistControls.(~storage_path, ~controls);
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
		~synths.do{ |syn| syn.set(\relaxtime, ez.value) };
		persistControls.(~storage_path, ~controls);
	},
	initVal: 0.01,
	labelWidth: 60;
);
w.view.decorator.nextLine;
~controls[\gain] = EZSlider( w,         // parent
	290@20,    // bounds
	\gain,  // label
	ControlSpec(0, 10, \lin, 0.01, 1),     // controlSpec
	{ arg ez;
		~synths.do{ |syn| syn.set(\gain, ez.value) };
		persistControls.(~storage_path, ~controls);
	},
	initVal: 1,
	labelWidth: 60;
);


// auto read prefs file. create a default one if not there
data = Object.readArchive(thispath ++ "/" ++ "prefs.preset");

if (data.isNil, { // file wasn't there. create a default one
	var data = Dictionary[ // set default values
		\threshold -> 0.1,
		\relaxtime -> 0.01,
		\gain -> 1,
	];
	persistControls.(~storage_path, data);
}, {
	~storage_path = data[\storage_path];
});

// restore the values from the prefs
~synths.do{ |syn|
	syn.set(
		\threshold, data[\threshold],
		\relaxtime, data[\relaxtime],
		\gain, data[\gain],
	);
};
// set the sliders but dont trigger the action at this moment
~controls.keysDo{ |key|
	~controls[key].value_( data[key] );
};




// ONSET detection synth =>
SynthDef(\detector, { |in=0, threshold=0.06, relaxtime=0.01, blocksize=1024, gain=1|
	var plank_lvl, plank_idx, freq, hasFreq, baton_lvl, onsets, delayedOnsets, fft;
	var sdel = 0.04; // [threeinputs.scd] this is a small delay to skip the first chaotic miliseconds
	var plank_channels = NamedControl.kr(\plank_channels, [4, 5, 6]);

	var baton = SoundIn.ar(in) * gain;
	var planks = SoundIn.ar(plank_channels) * gain;
	var planklevels = WAmp.kr(planks, sdel);
	var freqs = Array.newClear(plank_channels.size);

	# plank_lvl, plank_idx = ArrayMax.ar(planklevels); // # val, index
	# freq, hasFreq = Pitch.kr(SoundIn.ar(in), ampThreshold:0.0001, median:7);

	plank_channels.do{ |plk_ch, i|
		freqs[i] = Pitch.kr(SoundIn.ar(plk_ch), ampThreshold:0.0001); // # freq, hasFreq
	};

	baton_lvl = WAmp.kr(baton, 0.1); // Window size should probably be around 50 ms? (0.05)

	fft = FFT(LocalBuf(blocksize), baton, wintype:1);
	onsets = Onsets.kr(fft, threshold, odftype:\power, relaxtime: relaxtime, mingap:4);
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
		freq,
		freqs[0][0],
		freqs[1][0],
		freqs[2][0],
	]);

}).add;




// MAIN =>
// Cannot be run until storage_path has been set
~main = { arg storage_path;
	// load the settings dictionary (~recInfo)
	(storage_path +/+ "rec_info.scd").load; // TODO: Add rec_info configs to GUI?

	if ((~inputDevice.size > 0), {
		Server.default.options.inDevice_(~inputDevice); // set to soundcard if needed
	});
	Server.default.options.numInputBusChannels_(~numInputChannels);
	s = Server.local;
	// s.meter(8, 8); // opens the meter window      /// FIXME: gets errors
	if (not(s.serverRunning), { s.boot }); // start server

	thisProcess.platform.recordingsDir = storage_path; // recordings will be stored here


	// Write recInfo to CSV file for posterity ->
	~writeConfig = {
		var filepath = storage_path +/+ "rec_info.csv";
		var csvfile = File(filepath, "w");
		var headers = "";
		var channels = "";

		// gather channel info
		~recInfo.keysValuesDo{ |key, val|
			headers = headers ++ key.asString ++ ",";
			channels = channels ++ val.value.asString ++ ",";
		};

		// TODO: Write controls values?
/*		~controls.keysValuesDo{ |key, val|
			headers = headers ++ key.asString ++ ",";
			channels = channels ++ val.value.asString ++ ",";
		};*/

		csvfile.write( headers );
		csvfile.write( "\n" );
		csvfile.write( channels );
		csvfile.close;
	}.();

	// Get channels for batons and planks ->
	~getChannels = {
		var channels = Dictionary[\baton -> [], \plk -> []];
		~recInfo.keysValuesDo{ |key, val|
			var in = key.asString.findRegexp("ch([0-9]+)");
			var ch = in[1][1].asInteger - 1;
			if ("p[0-9][rl]".matchRegexp(val), {
				channels[\baton] = channels[\baton].add(ch);
			});
			if ("plk[0-9]".matchRegexp(val), {
				channels[\plk] = channels[\plk].add(ch);
			});
		};
		channels;
	};

	// Returns channels to record ->
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


	s.waitForBoot{
		// get the batons to listen to from recInfo ->
		var channels = ~getChannels.();
		~synths!?.collect(_.free); // free synths in case they are still around
		~synths = List.new;
		channels[\baton].do{ |ch|
			// create onset detection synth for each baton
			~synths = ~synths.add( Synth(\detector, [\in, ch]).setn(\plank_channels, channels[\plk]) );
		};

		// Init GUI ->
		if (t.isNil, {
			t = TxalaRecGUI.new;
			t.doTxalaScore();
			t.updateNumPlanks(3);
		});
		t.setFileStoragePath(storage_path);
		t.setRecChannels(~getRecChannels.());
	};
};


// Wait until user has entered storage path ->
fork {
	~wait_for_path.wait({ (~storage_path.notEmpty) });
	"Storage path has been set to: '%'\n".postf(~storage_path);
	~main.(~storage_path);
};


// OSC server =>
OSCFunc({ arg msg;
	var args;

	// calculate timedelta ->
	var clock = msg[7].asFloat;
	var lasttime = if ((t.lasttime == 0), clock, t.lasttime);
	var timedelta = clock - lasttime;

	t.lasttime = clock;

	args = Dictionary[
		\baton -> msg[3].asInteger,
		\plank -> msg[5].asInteger,
		\baton_lvl -> msg[4].asFloat,
		\plank_lvl -> msg[6].asFloat, // salient plank level
		\timedelta -> timedelta,
		\clock -> clock,
		\plank_lvl_1 -> msg[8].asFloat,
		\plank_lvl_2 -> msg[9].asFloat,
		\plank_lvl_3 -> msg[10].asFloat,
		\pitch_baton -> msg[11].asFloat,
		\pitch_plk1 -> msg[12].asFloat,
		\pitch_plk2 -> msg[13].asFloat,
		\pitch_plk3 -> msg[14].asFloat,
	];

	t.hit(SystemClock.seconds, args[\baton_lvl], args[\plank], (args[\baton] + 1), args);

}, '/input');

)

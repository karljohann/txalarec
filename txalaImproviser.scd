(
~storage_path = "/Users/karljohann/Downloads/txalakynning/";
~wait_for_path = CondVar();

/*
// SETTINGS DIALOGUES =>
{ // calibration window with auto load/save prefs
	var data = Dictionary.new;
	var thispath = thisProcess.nowExecutingPath.dirname;
	var persistControls;
	var labelWidth = 80;
	var boundWidth = 360;
	~controls = Dictionary.new;
	w = Window(\Session_settings, (boundWidth + 10)@120).front;
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

	Button(w, boundWidth@20)
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
				// re-run main every time path is changed
				if ((old_path != ~storage_path), { // Only run if path changed
					~main.(~storage_path);
				});
			}, {
				"rec_info.scd does not exists in selected directory".postln;
			});
		},
		fileMode: 2,
		path: if (~storage_path.notEmpty, ~storage_path)
		)
	});
	w.view.decorator.nextLine;
	~controls[\threshold] = EZSlider( w,         // parent
		boundWidth@20,    // bounds
		"threshold",  // label
		ControlSpec(0, 1, \lin, 0.001, 0.06),     // controlSpec
		{ arg ez;
			~synths.do{ |syn| syn.set(\threshold, ez.value) };
			persistControls.(~storage_path, ~controls);
		},
		initVal: 0.06,
		labelWidth: labelWidth;
	);
	~controls[\threshold].numberView.maxDecimals = 3;
	w.view.decorator.nextLine;
	~controls[\relaxtime] = EZSlider( w,         // parent
		boundWidth@20,    // bounds
		"relax time",  // label
		ControlSpec(0, 1, \lin, 0.01, 0.01),     // controlSpec
		{ arg ez;
			~synths.do{ |syn| syn.set(\relaxtime, ez.value) };
			persistControls.(~storage_path, ~controls);
		},
		initVal: 0.01,
		labelWidth: labelWidth;
	);
	w.view.decorator.nextLine;
	~controls[\gain] = EZSlider( w,         // parent
		boundWidth@20,    // bounds
		\gain,  // label
		ControlSpec(0, 10, \lin, 0.01, 1),     // controlSpec
		{ arg ez;
			~synths.do{ |syn| syn.set(\gain, ez.value) };
			persistControls.(~storage_path, ~controls);
		},
		initVal: 1,
		labelWidth: labelWidth;
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
}.();
*/



MIDIClient.init;
MIDIClient.destinations;
MIDIOut.newByName("IAC Driver", "Bus 1");
m = MIDIOut(0);


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

	/*
	[
		in,
		baton_lvl,
		plank_idx,
		plank_lvl,
		Sweep.ar,
		planklevels[0],
		planklevels[1],
		planklevels[2],
		// *planklevels,
		freq,
		freqs[0][0],
		freqs[1][0],
		freqs[2][0],
	].postln;
	*/

	"hit".postln;

/*	if (in == 0, m.noteOn(0, note:0, veloc:90));
	if (in == 1, m.noteOn(0, note:1, veloc:90));
	if (in == 2, m.noteOn(0, note:2, veloc:90));
	if (in == 3, m.noteOn(0, note:3, veloc:90));*/

	SendReply.kr(delayedOnsets, '/input', [
		in,
		baton_lvl,
		plank_idx,
		plank_lvl,
		Sweep.ar,
		planklevels[0],
		planklevels[1],
		planklevels[2],
		// *planklevels,
		freq,
		freqs[0][0],
		freqs[1][0],
		freqs[2][0],
	]);

}).add;


/*
b = Bus.control(s, 2);    // a 2 channel control Bus
b.index;         // this should be zero
b.numChannels
(
a = Bus.control(s, 1).set(440);
b = Bus.control(s, 1).set(0.01);
)
(
SynthDef(\rlpf, { |out, ffreq, rq|
    Out.ar(out, RLPF.ar(WhiteNoise.ar(0.2), ffreq, rq))
}).play(s, [\ffreq, a.asMap, \rq, b.asMap]);
)
*/

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
	}.();

	// Get channels for batons and planks ->
	~channels = {
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
	}.();

	// Get channels for batons ->
	~playerChannels = {
		var players = Dictionary.new;
		~recInfo.keysValuesDo{ |key, val|
			var in = key.asString.findRegexp("ch([0-9]+)");
			var ch = in[1][1].asInteger - 1;
			if ("p[0-9][rl]".matchRegexp(val), {
				var p = val.findRegexp("p([0-9])[rl]");
				players[ch] = p[1][1].asInteger - 1;
			});
		};
		players;
	}.();


	s.waitForBoot{
		~synths!?.collect(_.free); // free synths in case they are still around
		~synths = List.new;
		~channels[\baton].do{ |ch|
			// create onset detection synth for each baton
			var synth = Synth(\detector, [\in, ch]);
			synth.setn(\plank_channels, ~channels[\plk]);
/*			~controls.keysValuesDo{ |key, item|
				synth.setn(key.asSymbol, item.value.asFloat)
			};*/
			~synths = ~synths.add(synth);
		};

		// Init GUI ->
		if (t.isNil, {
			t = TxalaRecGUI.new;
			t.doTxalaScore();
			t.updateNumPlanks(3);
		});
		t.setFileStoragePath(storage_path);
		t.setRecChannels(~recChannels);
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
	var args, args_dict, players;

	// calculate timedelta ->
	var clock = msg[7].asFloat;
	var lasttime = if ((t.lasttime == 0), clock, t.lasttime);
	var timedelta = clock - lasttime;
	t.lasttime = clock;

	args = [
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

	m.program(0, msg[3].asInteger);
	m.noteOn(0, note:msg[5].asInteger, veloc:90);

	args_dict = args.asDict; // to access the key-value in t.hit
	t.hit(
		hittime: SystemClock.seconds,
		amp: args_dict[\baton_lvl],
		plank: args_dict[\plank],
		stick: (args_dict[\baton] + 1),
		player: ~playerChannels[args_dict[\baton]],
	);

	if (t.isRecording, {
		t.writeCSV(args);
	});
}, '/input');









// MIDIClient.init;
// MIDIClient.sources;
// MIDIIn.newByName("IAC Driver", "Bus 2");
// m2 = MIDIIn(0);

// MIDIIn.connect;
// var midibus = MIDIIn.findPort("IAC Driver", "Bus 2");
// MIDIClient.sources.at(midibus)
// MIDIClient.sources.at(1)
MIDIIn.connect(1, 1);
// s.boot;


x = SynthDef("sik-goo", { |out, freq = 440, formfreq = 100, gate = 0.0, bwfreq = 800|
    var x;
    x = Formant.ar(
        SinOsc.kr(0.02, 0, 10, freq),
        formfreq,
        bwfreq
    );
    x = EnvGen.kr(Env.adsr, gate, Latch.kr(gate, gate)) * x;
    Out.ar(out, x);
}).add;


// x = Synth("sik-goo");

//set the action:

~noteOn = {arg src, chan, num, vel;
    x.set(\freq, num.midicps / 4.0);
    x.set(\gate, vel / 200 );
    x.set(\formfreq, vel / 127 * 1000);
	["yo", chan, num, vel].postln;
};
MIDIIn.addFuncTo(\noteOn, ~noteOn);
~noteOff = { arg src,chan,num,vel;
    x.set(\gate, 0.0);
};
MIDIIn.addFuncTo(\noteOff, ~noteOff);

//cleanup
MIDIIn.removeFuncFrom(\noteOn, ~noteOn);
MIDIIn.removeFuncFrom(\noteOff, ~noteOff);
)
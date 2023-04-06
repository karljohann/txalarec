
(
/**
* txalaImproviser.scd
*
* Planks:
* plk{1..n}
* example: "plk3" => plank 3
*
* Players:
* p{1..2}{l,r}
* example: "p2r" => player 2 right hand baton
*
*/
~recInfo = Dictionary[
	\ch1 -> "p1l",
	\ch2 -> "p1r",
	\ch3 -> "plk1",
	\ch4 -> "plk2",
];

// Name of soundcard, if not needed leave empty string
~inputDevice = "UMC404HD 192k";
// The number of output channels
~numInputChannels = 4;

// init midi
MIDIClient.init;
m = MIDIOut.newByName("IAC Driver", "Bus 1");
m.latency = 0;


// ONSET detection synth =>
SynthDef(\detector, { |in=0, threshold=0.6, relaxtime=0.01, blocksize=1024, gain=1|
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
		// *planklevels,
		freq,
		freqs[0][0],
		freqs[1][0],
		freqs[2][0],
	]);

}).add;



// MAIN =>
~main = {
	if ((~inputDevice.size > 0), {
		Server.default.options.inDevice_(~inputDevice); // set to soundcard if needed
	});
	Server.default.options.numInputBusChannels_(~numInputChannels);
	s = Server.local;
	if (not(s.serverRunning), { s.boot }); // start server

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
			~synths = ~synths.add(synth);
		};

		// Init GUI ->
		if (t.isNil, {
			t = TxalaRecGUI.new;
			t.doTxalaScore();
			t.updateNumPlanks(3);
		});
		t.setRecChannels(~recChannels);
	};
};


~main.();


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

	// map plank to note ->
	~map_planks = [41, 43, 45]; // planks 0, 1, 2 to notes 41, 43, 45
	~note = ~map_planks[msg[5].asInteger];
	~veloc = (msg[4].asFloat * 127 * 10).min(127).max(80).asInteger; // Very much not accurate

	// ["Midi", msg[3].asInteger, note:~note, veloc:~veloc].postln;
	m.noteOn(msg[3].asInteger, note:~note, veloc:~veloc);

	args_dict = args.asDict; // to access the key-value in t.hit
	// To display hits in UI
	t.hit(
		hittime: SystemClock.seconds,
		amp: args_dict[\baton_lvl],
		plank: args_dict[\plank],
		stick: (args_dict[\baton] + 1),
		player: ~playerChannels[args_dict[\baton]],
	);
}, '/input');
)


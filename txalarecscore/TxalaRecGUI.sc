// license GPL
// by www.ixi-audio.net




/*
usage:

var keys = [\baton, \plank, \baton_lvl, \plank_lvl, \timedelta]; // datum to be recorded to CSV file
~storage_path = "~/Downloads/txalaparta_recordings/session_test/"; // path to store recordings
~numInputChannels = 8; // number of channels on soundcard (0..~numInputChannels)
n = 3;

t = TxalaRecGUI.new;
t.doTxalaScore();
t.updateNumPlanks(n);
t.setFileStoragePath(~storage_path);
t.setCSVKeys(keys);
t.setChannelSize(~numInputChannels.asInteger);

p = true;

//w.mark(tempocalc.lasttime, SystemClock.seconds, txalasilence.compass, lastPattern.size)


fork{
	inf.do({arg i;
		p = p.not;
		t.hit(SystemClock.seconds, rrand(0.2, 1), p.asInt, n.rand); // time, amp, player, plank
		0.2.wait;
	});
};
t.close
*/

TxalaRecGUI {
	var parent;
	var txalascoreevents, txalascoremarks, txalascore, timelinewin, txalascoreF, txalascoresttime, csvfile, recChannels, <>channelSize;
	var isRecording = false;
	var storagepath = "~/"; // assuming unix-based OS
	var filepath, csvKeys;
	var <>lasttime = 0; // init time of last hit

	*new {
		^super.new.initTxalaScoreGUI();
	}

	initTxalaScoreGUI {
		this.reset()
	}

	reset {
		txalascoreevents = nil;
		txalascoremarks = nil;
		if (txalascore.isNil.not, {txalascore.events = nil; txalascore.marks = nil});
		txalascoreF = Routine({ // is a Routine the best way?
			inf.do({
				var frame = 40;
				if (txalascore.isNil.not, {
					txalascore.update( Main.elapsedTime - txalascoresttime );
				});
				0.05.wait; // 20fps. 1/20
			});
		});
	}

	setRecChannels { arg channel_arr;
		recChannels = channel_arr;
	}

	setFileStoragePath { arg path;
		storagepath = path.asString;
	}

	setCSVKeys { arg keys;
		csvKeys = keys;
	}

	initCSVFile { arg timestamp;
		var csvfile;
		var headers = "";
		// NOTE: storagepath and csvKeys have to be set first
		filepath = storagepath +/+ "sc_txala_rec_" ++ timestamp ++ ".csv";
		csvfile = File(filepath, "w");
		csvKeys.do{ |key|
			headers = headers ++ key.asString ++ ",";
		};
		csvfile.write( headers );
		csvfile.close;
	}

	writeCSV { arg args;
		// if (not(File.exists(filepath)), { // TODO: Check for race-condition
		// this.initCSVFile(filepath);
		// });

		csvfile = File(filepath, "a");
		csvfile.write("\n"); // write new line bc append does not
		csvKeys.do{ |key|
			csvfile.write( args[key].asString ++ ",");
		};
		csvfile.close;
	}

	changebg { arg on = true;
		var color = if (on, Color.white, Color.gray);
		txalascore.changebg(color);
	}


	hit { arg hittime, amp, plank=nil, stick=nil, rawData=nil;
		var hitdata, playerFromStick, player;
		if (txalascore.isNil.not, {
			hittime = hittime - txalascoresttime;
			player = if ((stick < 2), 0, 1);
			hitdata = ().add(\time -> hittime)
			            .add(\amp -> amp)
					    .add(\player -> player)
					    .add(\plank -> plank)
					    .add(\stick -> stick);
			txalascoreevents = txalascoreevents.add(hitdata);
			txalascore.events = txalascoreevents;
		});

		if (isRecording, {
			this.writeCSV(rawData);
		});
	}

	mark {arg sttime, endtime, compassnum, hitnum; // patterns time is relative to first hit. starts with 0
		var data;
		if (txalascore.isNil.not, {
			data = ()
			.add(\start -> (sttime - txalascoresttime))
			.add(\end-> (endtime - txalascoresttime))
			.add(\num-> compassnum)
			.add(\hits-> hitnum);
			txalascoremarks = txalascoremarks.add(data);
			txalascore.marks = txalascoremarks;
		});
	}

	close {
		if (timelinewin.isNil.not, {
			timelinewin.close();
			timelinewin = nil;
		});
	}

	updateNumPlanks { arg numplanks;
		// DO NOT UPDATE IF MODE 0?
		var mode = 0, tframe, group, planks;
		if (txalascore.isNil.not, {
			mode = txalascore.drawmode;
			tframe = txalascore.timeframe;
			group = txalascore.drawgroup;
			planks = txalascore.drawplanks;
		} );
		txalascore = nil;
		if ( (timelinewin.isNil.not), {
			txalascore = TxalaScore.new(timelinewin,
				Rect(0, 0, timelinewin.bounds.width, timelinewin.bounds.height-25), numplanks, tframe, mode, planks, group)
		});

		txalascore.drawplanks = true; // TODO

		this.changebg(false); // FIXME: This probably shouldnt be in this unrelated function
	}

	doTxalaScore { arg xloc=0, yloc=400, width=2040, height=700, timeframe=4, numactiveplanks=3;
		var view, xstep=0, drawspeed=1;
		if (timelinewin.isNil, {
			timelinewin = Window(~txl.do("Timeline"), Rect(xloc, yloc, width, height));

		    txalascoresttime = Main.elapsedTime;
			txalascore = nil;
			txalascore = TxalaScore.new(timelinewin,
				Rect(0, 0, timelinewin.bounds.width, timelinewin.bounds.height-25),
				numactiveplanks);

			txalascore.timeframe = timeframe;
			//tscore.recordScore = true;

			EZSlider( timelinewin,         // parent
				Rect(-40,timelinewin.bounds.height-22,200,20),    // bounds
				~txl.do("zoom"),  // label
				ControlSpec(20, 1, \lin, 0.001, 10, "ms"),     // controlSpec
				{ arg ez;
					txalascore.timeframe = ez.value;
				},
				initVal: timeframe,
				labelWidth: 80;
			);

			Button(timelinewin, Rect(200, (timelinewin.bounds.height - 22), 100, 20))
			.states_([
				["Record", Color.white, Color.green],
				["Stop", Color.white, Color.red]
			])
			.action_({ arg butt;
				// Server.default.record;
				if ((butt.value == 1), {
					{ SoundIn.ar(recChannels) }.play;
					Server.default.record(numChannels: 8);
					isRecording = true;
					this.changebg();
					this.initCSVFile(Date.getDate.stamp);
				}, {
					if ((butt.value == 0), {
						Server.default.stopRecording;
						isRecording = false;
						lasttime = 0;
						this.changebg(false)
					});
				});
			});

			AppClock.play(txalascoreF);

			timelinewin.onClose = {timelinewin=nil}; // only one instance please
			timelinewin.front;
			//timelinewin.alwaysOnTop = true;
		});
	}
}

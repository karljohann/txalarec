
TxalaRecScore {

	var win, view, sndview, >events, >marks, selected, timeoffset, image, record, recordtask, <numplanks;
	var <>drawmode=false, <>drawplanks=false, <>drawgroup=false, eventcutindex=0, markcutindex=0;
	var <timeframe = 12;
	var imageArray;

	*new {|parent, rect, numplanks=3, timeframe=12, drawmode = false, drawplanks=false, drawgroup = false|
		^super.new.initTxalaScore( parent, rect, numplanks, timeframe, drawmode, drawplanks, drawgroup );
	}

	initTxalaScore {|parent, rect, nplanks, tframe, dmode, dplanks, dgroup|
		var plankheight, localnumplanks=nplanks;
		selected = nil;
		win = parent;
		imageArray = [];
		timeframe = tframe;
		numplanks = nplanks; // store but dont use it now
		drawmode = dmode;
		drawplanks = dplanks;
		drawgroup = dgroup;


		numplanks.postln;

		// wave
		//sndview = SoundFileView.new(parent, rect);

		view = UserView.new(parent, rect);
		view.background = Color.white;//.alpha(1);

		plankheight = (view.bounds.height/(numplanks+1));

		view.drawFunc_({
			var factor = view.bounds.width/timeframe, frame=40;// To DO: frame should be dynamic acording to the zoom factor

			if (drawplanks.not, { localnumplanks = 1 }, {localnumplanks=numplanks}); // all planks in the same line
			plankheight = (view.bounds.height/(localnumplanks+1));

			// the time grid (vertical lines)
			Pen.color = Color.black.alpha_(0.2);
			20.do({arg i;
				Pen.line(Point((view.bounds.width/20)*i, 0), Point((view.bounds.width/20)*i, view.bounds.height));
			});
			Pen.stroke;

			//////////////
			if (drawgroup, {
				if (marks.isNil.not, { //avoid error with frame when marks is nil
					Pen.color = Color.green.lighten(0.5);
					//Pen.alpha = 0.3;
					marks[marks.size-frame..].do({arg mark;
						var startp, endp;
						startp = (mark.start-timeoffset) * factor;
						endp = ((mark.end-timeoffset) * factor ) - startp; // this is the width of the rectangle
						Pen.addRect( Rect(startp, view.bounds.top, endp, view.bounds.bottom) );
					});
					Pen.fill;

					Pen.color = Color.black;
					//Pen.alpha = 1;
					marks[marks.size-frame..].do({arg mark;
						var startp = (mark.start-timeoffset) * factor;
						Pen.stringAtPoint (mark.num.asString,
							Point(startp, view.bounds.height-10), Font( "Helvetica", 10 ));
						Pen.stringAtPoint (mark.hits.asString,
							Point(((mark.end-timeoffset) * factor ), view.bounds.height-10), Font( "Helvetica", 10 ));
					});
				});
			});

			// the planks
			Pen.color = Color.black.alpha_(0.2);
			localnumplanks.do({arg i;
				Pen.line(Point(0, plankheight*(i+1)), Point(view.bounds.width,plankheight*(i+1)));
			});
			Pen.stroke;

			// the events themselves
			Pen.color = Color.black;
			if (events.isNil.not, { //avoid error with frame when events is nil
				events[events.size-frame..].do({arg event; // just deal with the last ones
					var posy, labely, liney, plankpos, eventamp, eventplank;
					var time = (event.time-timeoffset) * factor;

					eventamp = event.amp;
					if ( ((event.player == 0) && drawmode), { eventamp = eventamp.neg }); // reverse
					eventplank = event.plank;
					if (drawplanks.not, {eventplank = 0});

					plankpos = view.bounds.height - (plankheight * (eventplank+1));
					posy =  plankpos - (eventamp*plankheight);
					liney = posy+8;

					if (event.amp == 1.neg, { // hutsune hit
						posy = -100;//OFF
						liney = 0;
						plankpos = view.bounds.height;
						Pen.width = 3;
					});

					Pen.color = if(event.player == 1, {Color.red}, {Color.blue});
					Pen.fillRect(Rect(time-4, posy, 8, 8)); // the square
					Pen.line( Point(time, plankpos), Point(time, liney) ); // the line
					Pen.stroke;

					Pen.color = Color.black;
					Pen.stringAtPoint( (event.plank+1).asString, Point(time+8, posy));
					if (event.stick.isNil.not, {
						Pen.stringAtPoint( (event.stick).asString, Point(time+8, posy+12))
					});

					Pen.width = 1; //back to normal
				});
			});
		});
	}

	// start the scrolling movement (better not use this and do it from the outside - see example)
	scrolling_ {arg bool;
		var task; // this needs to be declared above, if used;
		var offsettime = Main.elapsedTime;
		task = fork{
			inf.do({arg i;
				var now = Main.elapsedTime - offsettime;
				{this.update(events[events.size-40..], marks[events.size-40..], now)}.defer; // just display the last 40 items. TO DO: make this dynamicaccording to zoom level
				//{this.update(events, marks, now)}.defer;
				0.05.wait;
			});
		};
	}

	// is the score being recorded? (images saved to disk)
	recordScore_ {arg bool;
		record = bool;
		if(record, { // if starting recording
			recordtask = fork{
				inf.do({arg i;
					{this.grabScoreIntoImage(i)}.defer;
					timeframe.wait;
				});
			};
		}, { // if stopping
			var wwin, scrollview, userview;
			wwin = Window.new("score", win.bounds).front;
			scrollview = SCScrollView(wwin, Rect(0,0, win.bounds.width, win.bounds.height) );
			// now how to draw all the images into a Userview? Using imageArray? or images from disk? Python?
			userview = UserView.new(scrollview, Rect(0,0, scrollview.bounds.width*3, scrollview.bounds.height));
			userview.background_(Color.green);
			userview.drawFunc_({
				imageArray.do({arg image, i;
					image.drawAtPoint(Point(image.width*i, 0), Rect(0,0,2780, 800));
				//	Pen.imageAtPoint(image, Point(image.width*i, 0));
					userview.refresh;

				});
			});
		});

	}
	// the time it takes to scroll from right to left
	timeframe_{arg timef;
		timeframe = timef;
	}

	sortEvents {
		events = events.sort({arg e1, e2; e1.time <= e2.time });
	}

	update { |timeoff=0|
		timeoffset = timeoff-timeframe;
		view.refresh;
	}

	grabScoreIntoImage {arg number; /* this does not work under QT*/
		var tempimg;
		tempimg = Image.fromWindow(win, view.bounds);
		imageArray = imageArray.add(tempimg);
		tempimg.write(Platform.userHomeDir++"/txalascores/txalascore_"++number.asString++".png");
	}

	postEvents {
		" EVENTS ____________________ \n".postln;
		events.postln;
	}

	changebg { |bgcolor|
		view.background = bgcolor;
	}


}

/*

e = {arg i; ().add(\time -> (0.1+ (i/10))).add(\amp -> rrand(0.1, 0.9)).add(\player -> (2.rand+1)).add(\plank -> (3.rand+1))}!8;
w = Window.new("txalascore", Rect(100, 100, 800, 500)).front;
x = TxalaScore.new(w, Rect(10, 10, 600, 400));
x.timeframe =2;

x.update(e, 1);
x.postEvents;


e = {arg i; ().add(\time -> (0.1+ (i/10))).add(\amp -> rrand(0.1, 0.9)).add(\player -> (2.rand+1)).add(\plank -> (3.rand+1))}!8;
o = e.reject({arg event; event.player == 1})
t = e.reject({arg event; event.player == 0})

fork{
	20.do({
		e = {arg i; ().add(\time -> (0.1+ (i/10))).add(\amp -> rrand(0.1, 0.9)).add(\player -> (2.rand+1)).add(\plank -> (3.rand+1))}!8;
{x.update(e)}.defer;

		2.wait;
		})
	}

o = e.reject({arg event; event.player == 1})
t = e.reject({arg event; event.player == 0})


// ////////////////////

// example 1
(
w = Window.new("txalascore", Rect(100, 100, 1400, 500)).front;
x = TxalaScore.new(w, Rect(10, 10, 1400, 400), 3);

e = [];
t = Main.elapsedTime;

fork{
	inf.do({arg i;
		var newtime = Main.elapsedTime - t;
		e = e.add(().add(\time -> newtime).add(\amp -> rrand(0.1, 0.9)).add(\player -> (2.rand+1)).add(\plank -> (3.rand+1)));
		0.1.wait;
	});
};


fork{
	inf.do({arg i;
		var now = Main.elapsedTime - t;
		{x.update(e, now)}.defer;
		0.05.wait;
		})
	};

x.timeframe =6;

)

// example 2

b = Buffer.alloc(s, 512);

SynthDef(\onset, {arg buffer=0;
	var chain, onset, pitch, hasFreq, in, signal;
	in = SoundIn.ar(0);
	chain = FFT(buffer, in);
	onset = Onsets.kr(chain, 0.9, \rcomplex);
	#pitch, hasFreq = Tartini.kr(in);
	SendReply.kr(onset, '/onset', 1, pitch);
	//SendTrig.kr(onset, 1);
	//signal = WhiteNoise.ar(EnvGen.kr(Env.perc(0.001, 0.1, 0.2), onset));
	//Out.ar(1, signal);
}).store;

(
w = Window.new("txalascore", Rect(100, 100, 1400, 500)).front;
x = TxalaScore.new(w, Rect(10, 10, 1400, 400), 3);

e = [];
t = Main.elapsedTime;

Synth(\onset, [\buffer, b]);
t = Main.elapsedTime;

o = OSCdef(\listener, { arg msg, time;
	[time, msg].postln;
	e = e.add(().add(\time -> (time-t)).add(\amp -> rrand(0.1, 0.9)).add(\player -> (2.rand+1)).add(\plank -> (3.rand+1)));
},'/onset', s.addr);


fork{
	inf.do({arg i;
		var now = Main.elapsedTime - t;
		{x.update(e, now)}.defer;
		0.05.wait;
		})
	};

x.timeframe =22;

)
x.grabScoreIntoImage








///////// example 3 (Using x.recordScore = true, which stores images of the score to disk)

b = Buffer.alloc(s, 512);

(
w = Window.new("txalascore", Rect(100, 100, 1400, 500)).front;
x = TxalaScore.new(w, Rect(10, 10, 1400, 400), 3);

e = [];

Synth(\onset, [\buffer, b]);
t = Main.elapsedTime;

o = OSCdef(\listener, { arg msg, time;
	[time, msg].postln;
	e = e.add(().add(\time -> (time-t)).add(\amp -> rrand(0.1, 0.9)).add(\player -> (2.rand+1)).add(\plank -> (3.rand+1)));
},'/onset', s.addr);



fork{
	inf.do({arg i;
		var now = Main.elapsedTime - t;
		{x.update(e, now)}.defer;
		0.05.wait;
		})
	};

x.timeframe =6;
x.recordScore = true;

)
x.grabScoreIntoImage










///////// example 4 (Using x.recordScore = true, which stores images of the score to disk) but not onsets

b = Buffer.alloc(s, 512);

(
w = Window.new("txalascore", Rect(100, 100, 1400, 500)).front;
x = TxalaScore.new(w, Rect(10, 10, 1400, 400), 3);
t = Main.elapsedTime;

e = [];
m = [];

fork{
	inf.do({arg i;
		var newtime = Main.elapsedTime - t;
		e = e.add(().add(\time -> newtime).add(\amp -> rrand(0.1, 0.9)).add(\player -> (2.rand+1)).add(\plank -> (3.rand+1)));
		0.1.wait;
	});
};

fork{
	inf.do({arg i;
		var newtime = Main.elapsedTime - t;
m = m.add(().add(\time -> newtime));
		0.3.wait;
	});
};


fork{
	inf.do({arg i;
		var now = Main.elapsedTime - t;
		{x.update(e, m, now)}.defer;
		0.05.wait;
		})
	};

x.timeframe =6;
x.recordScore = true;

)
x.grabScoreIntoImage


////////////////////


*/


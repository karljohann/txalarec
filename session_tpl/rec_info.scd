/**
* rec_info.scd
*
* recInfo - information about channels in recording
* Planks:
* plk{1..n}
* example: "plk3" => plank 3
*
* Players:
* p{1..2}{l,r}
* example: "p2r" => player 2 right hand baton
*
* Miscellaneous:
* example: "dynamic_microphone"
*
* NOTE: Channels not registered here (or set to empty strings) will NOT be recorded
*
*/
~recInfo = Dictionary[
	\ch1 -> "p1l",
	\ch2 -> "p1r",
	\ch3 -> "p2l",
	\ch4 -> "p2r",
	\ch5 -> "plk1",
	\ch6 -> "plk2",
	\ch7 -> "plk3",
	\ch9 -> "",
];

// threshold=0.15, relaxtime=0.05, blocksize=1024, gain=0
// settings for each baton channel
~onsetSettings = Dictionary[
	\chA -> [\gain, 5],
	\ch4 -> [],
];

// Name of soundcard, if not needed leave empty string
~inputDevice = "16A";
// The amount of channels on soundcard
~numInputChannels = 8;

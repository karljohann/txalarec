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

// Name of soundcard, if not needed leave empty string
~inputDevice = "16A";
// "The number of output channels to record"
~numInputChannels = 8;
// "the offset at which to start to count the number of channels"
~fromBus = 0; // NOTE: do not change this unless you know what you are doing

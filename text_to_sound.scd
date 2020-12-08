// Unix command... generate sound files for each letter of engl alphabet
(
~alphabet = "abcdefghijklmnopqrstuvwxyz";
~alphNums = (97..121); // ??
~alphabetArray = Array.fill(~alphabet.size, {arg i, index; ~alphabet[i]});
)

// Unix commands to generate sound files: only for initial use

(
{
	var alph;
	alph = "abcdefghijklmnopqrstuvwxyz";
	alph.do({
		|item, i|
		item.postln;
		"say -v vicki" ++ "\"" ++ item ++ "\"" ++ "-o" ++ item ++ ".aiff".unixCmd;
	});
};
)

"ls".unixCmd;
"abcdefghijklmnopqrstuvwxyz".do({
	|item, index|
	{"say -v  zarvox \"" ++ item ++ "\" -o " ++ item ++ ".aiff"}.value.unixCmd; // Works
});

// Note: say outputs soound files at half of 44.1k Hz sample rate (22kHz)... upsample!

// Load sound files into arrayed buffers (?) in alphabetical order
// How allocate bufnums explicilty (ensure consistent execution) ?
// Run this first (allocate buffers)

(
~alphabet = "abcdefghijklmnopqrstuvwxyz";
Buffer.freeAll;
~alphabet.do({
	|item, index|
	Buffer.readChannel(s, File.getcwd ++ "/sound files/vicki/" ++ item ++ ".aiff", channels: 0);
});
)

// ALLOCATE BUFFNUMS TO AN ARRAY

// Bus Setup and allocation (please store in env variable)
// Can be run with rest b/c explicit bus numbers

// MAIN

(
~audioBus1 = Bus.new(rate: 'audio', index: 4, numChannels: 1, server: s); // Explicit index!!!
~audioBus2 = Bus.new(rate: 'audio', index: 5, numChannels: 1, server: s); // Explicit index!!!
~audioBus2.index;


// SynthDef that plays the letter it is given


SynthDef(\letter, {
	|letter, dur, out = 0, amp, rate = 0.5, freq = 440, sustain = 0.5, release = 0.5, trig = 1|
	var sig, chooseBuf, graintrig, env;
	env = EnvGen.kr(Env.asr(0.1, sustain, release), doneAction: 2, gate: trig);
	chooseBuf = letter; // Hitta på en mapping sen kolla bara om d funkar nu
	graintrig = LFNoise1.kr(freq) * env;
	sig = GrainSin.ar(numChannels: 1, trigger: graintrig, dur: 0.5, freq: freq, envbufnum: chooseBuf); // DO NOT EXPAND HERE
	Out.ar(out, sig);
}).add;


// Synth(\letter, [\letter, 24, \out, ~audioBus1]);
// x = Synth(\letter, [\letter, 25, \out, 0, \freq, 55]);
// x.set(\trig, 0);

// FFT SynthDef


SynthDef(\transform, {
	|inbus = 4, out = 5, amp, freezeRate = 1, shift = 1|
	var chain, fftBuf, input;
	fftBuf = LocalBuf(512);
	input = In.ar(inbus, 1);
	chain = FFT(fftBuf, input);
	// ADD FFT TRANSFORMS HERE
	chain = PV_BinShift(chain, stretch: shift, shift: shift, interp: 0);
	// chain = PV_MagFreeze(chain, SinOsc.kr(freezeRate));
	// chain = PV_PhaseShift(chain, 90, 1);
	Out.ar(out, IFFT(chain));
}).add;

SynthDef(\reverb, {
	|inbus = 5, out = 0, amp, dw = 0.5|
	var sig;
	sig = In.ar(inbus, 1);
	sig = FreeVerb.ar(sig, mix: dw)!2;
	Out.ar(out, sig);
}).add;

s.plotTree;

// ** //

// GUI for accepting text input
// EXLPICITLY ONLY WORKS WITH ALPHABETICAL CHARS

~fftTransformer.free;
~fftTransformer = Synth(\transform, [\out, ~audioBus2]);
 ~reverbBus.free;
~reverbBus = Synth(\reverb, [\dw, 0.5], addAction: 'addToTail');

~alphabet = "abcdefghijklmnopqrstuvwxyz";
~alphNums = (97..121); // ??
~alphabetArray = Array.fill(~alphabet.size, {arg i, index; ~alphabet[i]});

// Make Lookup table for conversion of alphabeticals to integers 0 through 25...

~lookupTable = [~alphabetArray.collect({|item, index| item.asSymbol;}), (1..26)].lace; // Changed from 0 to 1 (!!!)
~lookupTable = Dictionary.newFrom(~lookupTable);

// Function for looking up a given string (warning no arity – should prob be conditional on input being char (string, len 1?) or else return nil)

~charToIntFunc = {
	|input|
	if ( input.notNil.and({input.isAlpha}), {~lookupTable.at(input.toLower.asSymbol);}, { 0 });
};

// How do I write evaluation for multiple truthiness?

Window.closeAll;
~bgImage = Image.open(File.getcwd ++ "/images/gui.png"); // Make file relative to project root
~bgImage.bounds;
~mainWindow = ~bgImage.plot("Text", Rect(400, 200, 800, 600), showInfo: false);
~inputText = TextField(~mainWindow, Rect(10, 10, 780, 30))
	.font_(Font("Ableton Sans Medium Regular")
	.size_(18))
	.stringColor_(Color.new(1,1,1,1)).background_(Color.new(1,1,1,0)).align_(\center);
~staticText = StaticText(~mainWindow, Rect(370,270,60,60))
	.font_(Font("Ableton Sans Medium Regular")
	.size_(36))
	.align_(\center)
	.stringColor_(Color.new(1,1,1,1));

~inputButton = Button(~mainWindow, Rect(380, 70, 40, 40))
.states_([["Parse"],["Stop"]]).action_({
	|b|
	"BUTTON STATE" ++ b.value.postln;
	if (b.value == 1, {

	~dataSet = Array.newFrom(~inputText.value);

	~routineMain = Routine.new({
		|in|
		var first, last, durations, notes, majmin, scale;
		durations = ~dataSet.collect({ |item, index| ~charToIntFunc.value(item)});
		durations.postln;
		notes = durations.collect({|item| item.linlin(1, 26, 0, 7)});
		notes.midicps.postln;
		scale = Scale.choose(7); // MAKE NON RANDOM LATER
		scale.degrees.postln;
		first = ~dataSet.first;
		last = ~dataSet.last;
		majmin = ~charToIntFunc.value(first) - ~charToIntFunc.value(last);
		majmin.postln;

		// Define "musical events"
		// Collect and deploy:
		
		~dataSet.collect({ |item, index|
			var delta, charToInt, playingSynth;
			charToInt = ~charToIntFunc.value(item);
			delta = charToInt - ~charToIntFunc.value(~dataSet[(index + 1)]); // Crashar på sista char (!)
			if ( item.isAlpha == false, { 1.wait }, // Deals w/ whitespace, punctuation, could be better
			{ item.postln; ~playingSynth = Synth(\letter, [\letter, (charToInt -1), \out, ~audioBus1, \freq, 55]);
				// ~fftTransformer.set(\freezeRate, charToInt / 10);
				~fftTransformer.set(\shift, charToInt / 10);
				{
					~staticText.string_(item.toUpper);
				}.defer;
				delta.postln;
				{durations[index] / 10}.value.wait;
				~playingSynth.set(\trig, 0);
			});

		});
	});

	~routineMain.play;
	}, {
		~routineMain.stop;
		~playingSynth.set(\trig, 0);
	});
});
s.plotTree;
~mainWindow.front;
)

// Function for parsing text...

// Använd local scope variables om transformationen inte behövs i environment
// Men det vet vi ju inte riktigt än...

	// Wrap text? How long... is too long...
	// 140 chars! Or 280...
	// Split set into pairs, tris, and quads
	// Wrap at integer divisions to ensure consistency
	// Operate on pairs, tris, quads
	// Use multidimensional array?
	// Åke Hodel: Iiiiiiiiiiiiiiii-gevÄääääääää
	// Permuteringar på guds namn (.powerset) ... kanske inte
	// Wovel / consonants (todo)
	// Whitespace slicing (check! typ)

// Kräver nån sorts reset för att börja om !
// Ooh postcln... så ser man vilket objekt som gör vad...

Synth(\default, [\freq, 61.midicps]);

// SLASK

	Pbind.new(
		\instrument, \letter,
		\out, ~audioBus1,
		\letter, (Pseq([
			~lookupTable.at(~dataSet[0].toLower.asSymbol) // Solved uppercases

		], 1)),
	).play;

r = Routine.new( { 1.yield; 2.yield } );
r = Routine.new( { 10.collect({|item, index| item.yield}) } );

	~dataEnumerated = ~dataSet.ascii.linlin(-128, 127, 1, 256).postcln; // Lmao...
	~dataSquashed = ~dataEnumerated.linlin(1,256, 0, 1);
	~parseText.string_(~inputText.value);
	~dataSet = ~inputText.value;

k = Scale.choose(7);
k.degrees;

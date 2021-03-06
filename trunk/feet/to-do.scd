MIDIPort.init([3]);
MIDIPort.autoFreeSockets = false;

s.options.preferredDeviceFunc_(nil).device_("Aggregate Device");

BP.loadGui;

// NOT THIS ONE!! MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

(Document.current.path.dirname.dirname +/+ "common/common-defs.scd").loadPath;
(Document.current.path.dirname +/+ "feet-defs.scd").loadPath;

~master.doWhenReady { PeakMonitor(~master) };


m = MixerChannel(\test1, s, 1, 2/*, level: 0.1*/, outbus: ~master);
n = MixerChannel(\test2, s, 2, 2/*, level: 0.1*/, outbus: ~master);
m => MCG(0); n => MCG(1);

[m, n].do { |mx|
	// mx.outbus = ~master;
	mx.sendsSignalTo(~glrvbmc);
	mx.sendsSignalTo(~lcrvbmc);
};

~master => MCG(7);
~glrvbmc => MCG(5);
~lcrvbmc => MCG(6);

PeakMonitor(m);
PeakMonitor(n);
PeakMonitor(~master);
PeakMonitor(~glrvbmc);


[~glrvb, ~lcrvb].do(_.run(false)); [~glrvbmc, ~lcrvbmc].do(_.mute(true));
[~glrvb, ~lcrvb].do(_.run(true)); [~glrvbmc, ~lcrvbmc].do(_.mute(false));

VoicerProxy.new => VP.prNew(0);
4.do { VP(0).v.addControlProxy(VoicerGCProxy(nil, VP(0).v), addAlways: true) };
VP(0).v.gui;


/**** TODO Slide/inversion gesture */

Fact(\opening) => BP(\op);
Fact(\openingSteps) => BP(\st);

p = BP(\st);

p.gestures.lauraslide = { |parms|
	var env = Env([0, rrand(-25, -12), rrand(15, 30), 6], #[1, 1, 1.5].normalizeSum * 0.8, \sin);
	// var env = Env([0, rrand(30, 45)], #[1], \sin);
	Pbindf(~gestures[\slowStepStretch].(parms.copy.put(\numEv, 2)).drop(2),
		\instrument, \pvplayPanEnvShiftDist,
		\env, Pfunc { env }
		// \shiftS, -100,
		// \shiftE, 100,
		// \shiftFreq, rrand(2.0, 5.0, inf)
	).trace(prefix: "\n")
};
// ^^ NOT WORKING

// good enough:
p.runningNotes = (
	lauraslide: Pseries(
		{ rrand(-7, 0) },
		Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
		Pkey(\numEv).asStream
	),
	inversion1: Pseries(
		{ rrand(-3, 4) },
		Pstutter(
			Pseq([Pfuncn({ |ev| (ev[\numEv] * 0.6).round }), 100], 1),
			Pseq([1, -1], 1)
		) * Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
		Pkey(\numEv).asStream
	),
	inversion2: Pseries(
		{ rrand(0, 8) },
		Pstutter(
			Pseries(1, 1, inf),
			Pseq([1, -1], inf, 0 /*, { 2.rand }*/)
		) * Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
		Pkey(\numEv).asStream
	)
);

p.gestures.lauraslide = { |parms|
	Pbind(
		\numEv, parms[\numEv],
		\instrument, Pn(\bufGrainPanKlankDist, parms[\numEv]),
		\delta, 0.4 * Pexprand(0.8, 1.25, inf)
			* Pgeom.fromEndpoints(parms[\startDelta] ?? { rrand(0.35, 0.6) }, rrand(0.1, 0.2),
				parms[\numEv]),
		\amp, BPStream(\amp) * 0.04,  // filters are LOUD
		\numNotes, parms[\numNotesPat] ?? { Pwrand(#[1, 2, 3], #[1, 4, 3].normalizeSum, inf) },
		\filtDegree, (~runningNotes[parms[\notesKey] ? \lauraslide].value(parms)
			+.x Pseries(0, Pwrand(#[-1, -2, -3], #[1, 2, 2].normalizeSum, Pkey(\numNotes).asStream), inf))
			.clump(Pkey(\numNotes)),
		\filtFreq, Pkey(\filtDegree).collect { |deg| Mode(\g).cps(deg + 35) },
		\filtAttack, 0.01,
		\filtDecay, Pseries.fromEndpoints(0.2, 2.75, parms[\numEv]),
		\filtAmp, BPStream(\kamp),
		\chorusFreq, parms[\chorusFreq] ?? { Pstutter(inf, Pwhite(0.05, 0.11, inf)) },
		\chorusAmt, parms[\chorusAmt] ?? { 0.02 },
		\chorusDelay, parms[\chorusDelay] ?? { 0.03 },
		\chorusAmps, parms[\chorusAmps] ?? { [~defaultChorusAmps] },
		\harm, parms[\harm] ?? { [~defaultKlankHarm] },
		\amps, parms[\amps] ?? { [~defaultKlankAmps] },
		\decays, parms[\decays] ?? { [~defaultKlankDecays] },
		\pan, sin(Pseries(0, Pseries.fromEndpoints(0.08, 0.33, parms[\numEv]), inf) * 2pi)
			* #[-1, 1].choose,
		\distance, Pseries.fromEndpoints(parms[\startY] ? 20, 5, parms[\numEv])
	)
};

p.gest = \lauraslide;
p.autoRun = false;

p.autoRun = true;
p.gDelta = 2.5;
~saveNumEv = p.numEv;
p.numEv = Pwhite(8, 15, inf);

p.reset;
p.play;
p.runGesture((gest: \lauraslide, numEv: rrand(8, 14).postln));
p.runGesture((gest: \lauraslide, numEv: rrand(8, 14).postln, notesKey: \inversion1));

p.runGesture((gest: \lauraslide, numEv: 10));
p.runGesture((gest: \lauraslide, numEv: 12, notesKey: \inversion1));
p.runGesture((gest: \lauraslide, numEv: rrand(12, 19), notesKey: \inversion2, startDelta: rrand(0.65, 0.85), startY: 8));


p.runGesture((gest: \slowStepStretch, numEv: 8));

p.stop;

p.gDelta = Pwhite(0.5, 2.5, inf);
p.numEv = ~saveNumEv;




o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;

o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;


/**** TODO Leaning */

// use waterpad, with randomized freqmul for wobbling

Fact(\waterpad) => VC(\wp);
// SynthDescLib.at(VC(\wp).nodes[0].defname.asSymbol).msgFunc.def.argNames;

// mandatory! (now in factory)
SynthDescLib.at(VC(\wp).nodes[0].defname.asSymbol).msgFuncKeepGate = true;

SynthDef(\krwobble, { |outbus, sustain = 1|
	var	envOne = Env.one.asArray,
		speedEnv = NamedControl.kr(\speedEnv, (0 ! 32).overWrite(envOne)),
		speed = EnvGen.kr(speedEnv, timeScale: sustain),
		widthEnv = NamedControl.kr(\widthEnv, (0 ! 32).overWrite(envOne)),
		width = EnvGen.kr(widthEnv, timeScale: sustain),
		fmul = LFDNoise1.kr(speed).exprange(width.reciprocal, width);
	Out.kr(outbus, fmul);
}).add;

z = VC(\wp).nodes[0];

e = ProtoEvent(\polySynthKrBusLock).copy.putAll((
	instrument: z.defname.asSymbol,
	chan: VC(\wp).env.target,
	busRate: \control,
	numCh: 1,
	gate: 0.1,
	freq: 60.midicps * [1, 5/4, 3/2],
	sustain: 7,
	bufbase: VC(\wp).env.wt[0][0].bufnum,
	freqmul: { ~lock.bus.asMap },  // asControlInput .value's this
	lpcEv: (
		instrument: \krwobble,
		sustain: 7,
		speedEnv: Env(#[1.2, 5, 0.7], #[0.3, 0.7]),
		// widthEnv: Env(#[1.25, 1.25], #[1])
		widthEnv: Env(#[1, 1.8, 1], #[0.7, 0.3], \exp)
	)
));

f = e.copy.play;
s.controlBusAllocator.debug;

f.node.choose.trace;

f.lock.killNodes.trace;

f.lock.listVars
f.lpcEv


(play: {
	p.runGesture(currentEnvironment)
}) => ProtoEvent(\runKlankMachine);
ProtoEvent.composite(#[polySynthKrBusLock, runKlankMachine]) => ProtoEvent(\leaning);

q = Pseq([
	Pbind(
		\protoEvent, \polySynthKrBusLock,
		\chan, VC(\wp).env.target,
		\instrument, VC(\wp).nodes[0].defname.asSymbol,
		\busRate, \control,
		\numCh, 1,
		\gate, 0.1,
		\deg, (Pwhite(35, 45, inf) +.x Pseries(0, Prand(#[-1, -2, -3], 2))).clump(2),
		\freq, Pfunc { |ev| Mode(\g).cps(ev[\deg]) },
		// \delta, Pwhite(0.9, 1.4, inf),
		\delta, Pwhite(0.2, 0.4, inf) * Pseq(#[1, 2.1], { rrand(2, 4) }),
		\sustain, 9,
		\bufbase, Prand(VC(\wp).env.wt.flop[0], inf),
		\envAtk, 0.05,
		\envDcy, 0.12,
		\fenv_tscale, Pkey(\sustain),
		\fenvProp, 0.07,
		\freqmul, { ~lock.bus.asMap },  // asControlInput .value's this
		\lpcEv, Pbind(
			\instrument, \krwobble,
			\speedEnv, Pfunc({ Env(#[1.2, 5, 0.7], #[0.3, 0.7]) }),
			\widthEnv, Pfunc({ Env(#[1, 1.05, 1], #[0.7, 0.3], \exp) })
		) <> Pfunc { |inev| inev.copy[\chan] = nil }
	),
	(protoEvent: \runKlankMachine,
		gest: \klankMachine, prob: 1, newDelta: 0.11, freq: 900, timeMul: 0.05, kAmp: 1, harm: (1, 3 .. 9), yEnds: #[5, 20], numEv: 12, start: p.pt.choose * 44100, delta: 1
	)
], 1).play(protoEvent: ProtoEvent(\leaning).copy);

q.stop;


p = BP(\st);
p.autoRun = false;

// startFrame was the missing bit
p.runGesture((gest: \klankMachine, prob: 1, newDelta: 0.09, freq: 900, timeMul: 0.05, kAmp: 1, harm: (1, 3 .. 9), yEnds: #[5, 20], numEv: 12, start: p.pt.choose * 44100));



/**** TODO Falling */

// like leaning, but more klank events
// pattern for frequency - usually dropping(?)



/**** TODO Conflict */

Fact(\opening) => BP(\op);
Fact(\openingSteps) => BP(\st);

p = BP(\st);
p.autoRun = false;
p.ffreqCtl.value = 4000;

p.runGesture((gest: \klankMachine,
	prob: 1,
	excTime: 0.08,
	newDelta: 0.35,
	freq: #[37, 43, 47].midicps,
	timeMul: 0.05,
	kAmp: 1,
	harm: (1, 3 .. 9),
	yEnds: #[18, 5],
	numEv: 4,
	start: p.pt.choose * 44100,
	rate: Pexprand(0.6, 0.8, inf)
));

// higher variation is almost snare-drummy
// provide newDelta rhythms


(
if(r.isPlaying) { r.stop };
r = fork {
	var g, c = Condition.new;
	loop {
		p.use {
			g = p.makeGesture((
				gest: \klankMachine,
				prob: 1,
				excTime: 0.08,
				newDelta: rrand(0.22, 0.4),
				// ominous
				freq: \patRejectLastN.eval(Pwhite(34, 52, inf), 3).clump(3).midicps,
				// freq: \patRejectLastN.eval(Pwhite(76.0, 94.0, inf), 3).clump(3).midicps,
				// freq: { rrand(76.0, 94.0).midicps } ! 3,
				timeMul: 0.03,
				kAmp: 1,
				harm: (1, 3 .. 9),
				yEnds: #[18, 5],
				numEv: rrand(4, 7),
				start: p.pt.choose * 44100,
				rate: 1.2, //Pexprand(0.6, 0.8, inf),
				shapebuf: b,
				// chorusDelay: Pwhite(0.05, 0.09, inf),
				// chorusAmt: Pwhite(0.5, 0.9, inf) * Pkey(\chorusDelay),
				chorusAmps: #[0.4, 0.4, 0.4],
				glrvbamt: 0.25,
				lcrvbamt: 0.14
			)).asStream;
		};
		g = CleanupStream(g, { c.unhang });
		p.use { ~spawner.par(g) };
		c.hang;
		1.wait;
	}
};
)

r.stop;

x = (Pseries.fromEndpoints(-1.0, 1.0, 512).asStream.all * 6.1887796806608).distort;
x.plot2;

b = Buffer.sendCollection(s, x.as(Signal).asWavetable, wait: 0.05);
b.sendCollection(x.as(Signal).asWavetable, wait: 0.05);

q = BP(\st).chan.playfx(Instr("busfx.dist"), [0, 2]); q.gui;


u.remove;
u = Updater(BP(\st), { |obj, what, more|
	if(more == \stopped) { r.stop };
});

(
if(r.isPlaying) { r.stop };
r = fork {
	var g, c = Condition.new;
	thisThread.clock.timeToNextBeat.debug.wait;
	loop {
		g = p.makeGesture((
			gest: \klankMachine,
			prob: 1,
			excTime: 0.08,
			newDelta: //Plazy({ |ev|
				Pfin({ |ev| ev[\parms][\numEv] }, Pnsym(
					Pfsm([
						(0..7),
						one: (1..8).dup(2).flat ++ #[0],
						dot: #[1, 3, 4, 5],
						revdot: #[0, 2, 4, 5, 6],
						rattata: #[0, 1, 3, 5, 7],
						ratatat: #[0, 1, 2, 3, 5, 6, 8],
						syncop: #[0, 1, 3],
						tripletHead: #[6, 8, 0],
						tripletTail: #[7, 8, 0],
						triplets: #[0]
					]),
					(	one: Pn(1, 1),
						dot: Pseq(#[0.75, 0.25], 1),
						revdot: Pseq(#[0.25, 0.75], 1),
						rattata: Pseq(#[0.5, 0.25, 0.25], 1),
						ratatat: Pseq(#[0.25, 0.25, 0.5], 1),
						syncop: Pseq(#[0.25, 0.5, 0.25], 1),
						tripletHead: Pseq([Pn(1/6, 3), 0.5], 1),
						tripletTail: Pseq([0.5, Pn(1/6, 3)], 1),
						triplets: Pn(1/6, 6)				
					)
				) * (60/104))
//			})
			,
			// ominous
			freq: \patRejectLastN.eval(Pwhite(34, 52, inf), 3).clump(3).midicps,
			// freq: \patRejectLastN.eval(Pwhite(76.0, 94.0, inf), 3).clump(3).midicps,
			// freq: { rrand(76.0, 94.0).midicps } ! 3,
			timeMul: 0.03,
			kAmp: 1,
			harm: (1, 3 .. 9),
			yEnds: #[18, 5],
			numEv: 25,
			start: p.pt.choose * 44100,
			rate: 1.2, //Pexprand(0.6, 0.8, inf),
			shapebuf: p.shapebuf,
			// chorusDelay: Pwhite(0.05, 0.09, inf),
			// chorusAmt: Pwhite(0.5, 0.9, inf) * Pkey(\chorusDelay),
			chorusAmps: #[0.4, 0.4, 0.4],
			glrvbamt: 0.25,
			lcrvbamt: 0.14
		));
		p.use { ~spawner.par(CleanupStream(g.asStream, { c.unhang })) };
		c.hang;
		thisThread.clock.timeToNextBeat.wait;
		// 1.wait;
	}
};
)

p.snareParms = { |parms(Event.new)|
	(	gest: \klankMachine,
		prob: 1,
		excTime: 0.08,
		newDelta: Pfin({ |ev| ev[\parms][\numEv] }, Pnsym(
			parms[\rhythms] ?? { Pfsm([
				(0..7),
				one: (1..8).dup(2).flat ++ #[0],
				dot: #[1, 3, 4, 5],
				revdot: #[0, 2, 4, 5, 6],
				rattata: #[0, 1, 3, 5, 7],
				ratatat: #[0, 1, 2, 3, 5, 6, 8],
				syncop: #[0, 1, 3],
				tripletHead: #[6, 8, 0],
				tripletTail: #[7, 8, 0],
				triplets: #[0]
			]) }, ~snareRhythms
		) * (parms[\tempo] ?? { (60/104) })),
		// ominous
		freq: parms[\freq] ?? { \patRejectLastN.eval(Pwhite(34, 52, inf), 3).clump(3).midicps },
		timeMul: 0.03,
		kAmp: parms[\kAmp] ?? {
			if(parms[\numEv] > 1) {
				Pseries.fromEndpoints(parms[\startAmp] ? 0.07, 1.0, parms[\numEv] ? 25)
			} { 1 }
		},
		harm: (1, 3 .. 9),
		yEnds: #[18, 5],
		numEv: parms[\numEv] ? 25,
		start: ~pt.choose * 44100,
		rate: 1.2, //Pexprand(0.6, 0.8, inf),
		shapebuf: ~shapebuf,
		chorusAmps: #[0.4, 0.4, 0.4],
		glrvbamt: 0.25,
		lcrvbamt: 0.14
	)
};

p.runGesture(p.snareParms((numEv: 2, rhythms: Pn(\one, 1), kAmp: 1)));

p.runGesture(p.snareParms((numEv: 3, rhythms: \ratatat, kAmp: 1)));

p.snareRhythms[\ratatat].estimateLength

f = { |gest(\one)|
	p.runGesture(p.snareParms((numEv: max(2, p.snareRhythms[gest].estimateLength), rhythms: Pn(gest, 1), kAmp: 1)));
};

f.(p.snareRhythms.keys.choose)



o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;

o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;


p.gestures.klankMachine = { |parms|
	var	instr = if(parms[\shapebuf].notNil) { \bufGrainPanKlShpDist } { \bufGrainPanKlankDist },
		list = [
			#[pan, distance], ~xyPat.(parms),
			\instrument, Pif((parms[\prob] ? 1).asPattern.coin, instr, \rest),
			\delta, parms[\newDelta] ? 0.5,
			// exciter time only - note dur is from filtDecay
			\time, parms[\excTime] ?? { min(0.15, Pkey(\delta) * 0.7) },
			\rate, parms[\rate] ? 1,
			\filtFreq, parms[\freq] ? Plazy { |ev| Pn(~kfreqStream.next(ev), inf) },
			\filtDecay, Pkey(\delta) * (parms[\timeMul] ? 1),
			\filtAttack, Pkey(\filtDecay) * 0.05,
			\filtAmp, parms[\kAmp] ?? { ~kAmpCtl.asMap },
			\ffreq, ~ffreqCtl.asMap,
			\lprq, 0.32, //~rqCtl.asMap,
			\amp, 0.5,
			\harm, parms[\harm] ?? {
				Pstutter(Pwhite(3, 6, inf), Pwrand([
					(1..5),
					(1, 3 .. 9),
					Pfuncn({ (1..5) * ({ rrand(0.9, 1.111) } ! 5).put(0, 1) })
				], #[0.4, 0.4, 0.2], inf).collect([_]))
			},
			\amps, Pkey(\harm).reciprocal,
			\chorusDelay, parms[\chorusDelay] ? 0.03,
			\chorusAmt, parms[\chorusAmt] ? 0.02,
			\chorusAmps, [parms[\chorusAmps] ? #[1, 1, 1]],
			\glrvbamt, parms[\glrvbamt] ? 0.075,
			\lcrvbamt, parms[\lcrvbamt] ? 0.035
		];
	if(parms[\start].notNil) {
		list = list ++ [start: parms[\start]];
	};
	if(parms[\shapebuf].notNil) {
		list = list ++ [
			shapebuf: parms[\shapebuf],
			shapeXf: parms[\shapeXf] ? 1
		]
	};
	Pbind(*list)
};




/**** TODO Multiple speeds */

Fact(\opening) => BP(\op);
Fact(\openingSteps) => BP(\st);

p = BP(\st);

p.gestures.keys
p.gestures[\klankHarmonize].postcs
p.gestures[\clatter].postcs
p[\xyPat].postcs

SynthDescLib.at(\bufGrainPanKlankDist).controls.do(_.postln); ""


// add to feet-defs later?
// not quite right - want to make notes crispier
p.kAmpCtl = GenericGlobalControl(\kAmp, nil, 1, \amp);
p.kAmpCtl.gui;

p.ffreqCtl = ~ffreq = GenericGlobalControl(\ffreq, nil, 18000, \freq);
p.rqCtl = ~rq = GenericGlobalControl(\rq, nil, 1, \myrq);

[~ffreq, ~rq].do({ |gc| gc => VP(3) });
p.kAmpCtl => VP(3);

~ffreq.watch.automate({ LFNoise1.kr(1.8).exprange(3000, 6000) }, target: BP(\st).chan.synthgroup, addAction: \addToHead);
~ffreq.stopWatching.stopAuto;

p.gestures.klankMachine = { |parms|
	Pbind(
		#[pan, distance], ~xyPat.(parms),
		\instrument, Pif(parms[\prob].asPattern.coin, \bufGrainPanKlankDist, \rest),
		\delta, parms[\newDelta] ? 0.5,
		\time, min(0.15, Pkey(\delta) * 0.7),  // exciter time only - note dur is from filtDecay
		\filtFreq, parms[\freq] ? Plazy { |ev| Pn(~kfreqStream.next(ev), inf) },
		\filtDecay, Pkey(\delta) * (parms[\timeMul] ? 1),
		\filtAttack, Pkey(\filtDecay) * 0.05,
		\filtAmp, ~kAmpCtl.asMap,
		\ffreq, ~ffreqCtl.asMap,
		\lprq, 0.32, //~rqCtl.asMap,
		\amp, 0.5,
		\harm, Pstutter(Pwhite(3, 6, inf), Pwrand([
			(1..5),
			(1, 3 .. 9),
			Pfuncn({ (1..5) * ({ rrand(0.9, 1.111) } ! 5).put(0, 1) })
		], #[0.4, 0.4, 0.2], inf).collect([_])),
		\amps, Pkey(\harm).reciprocal
	)
}

p.autoRun = false;

// p.autoRun = true;
// p.gDelta = 2.5;
// ~saveNumEv = p.numEv;
// p.numEv = Pwhite(8, 15, inf);

p.reset;
p.play;

p.runGesture((gest: \klankMachine, yEnds: #[5, 20], newDelta: 1.2, freq: 40.midicps, numEv: 10, timeMul: 0.5));
p.runGesture((gest: \klankMachine, yEnds: #[5, 20], newDelta: 0.3, freq: 50.midicps, numEv: 20, timeMul: 0.6));

q = Pbind(
	\play, {
		p.runGesture(currentEnvironment)
	},
	\gest, \klankMachine,
	\yEnds, #[5, 20],
	\midi, Pn(Pshuf(#[40, 50, 59, 66, 79], 1), inf),
	\freq, Pkey(\midi).midicps,
	\newDelta, 1.2 / (Pkey(\midi) - 20) * 20,
	\numEv, (5 / Pkey(\newDelta)).round,
	\timeMul, 0.5,
	\delta, Pwhite(0.8, 2.2, inf)
).play;

q.stop;
p.stop;


x = [
	#[40, 50, 59, 66, 79, 85],
	#[43, 52, 54, 59, 69, 78],
	#[45, 55, 62, 73, 76, 83]
].mapMode(\d);

q = Pbind(
	\play, {
		p.runGesture(currentEnvironment)
	},
	\gest, \klankMachine,
	\yEnds, #[5, 20],
	\range, Pn(Pshuf((0..5), 1), inf),
	\x, Pstutter(Pwhite(6, 14, inf), Pxrand(x, inf).trace),
	\newDelta, Pkey(\range).linexp(0, 5, 1.2, 0.09) * Pwhite(1.0, 1.2, inf),
	\numEv, (8 / Pkey(\newDelta)).round,
	\prob, Pkey(\range).linlin(0, 5, 1, 0.66),
	\freq, Pfunc({ |ev|
		var i = ev[\range],
			n = ev[\numEv],
			n1 = (n * rrand(0.4, 0.65)).roundUp,
			n2 = ((n - n1) * 0.5).trunc,
			adder = Pwrand(#[0, 1, 2, 3], #[1.5, 2, 2, 1].normalizeSum, n2);
		if(i >= 4) {
			adder = Pfin(n2, Ppatlace([adder, 0, 0], inf))
		};
		Pseries(ev[\x][i], Pseq([
			Pn(0, n1),
			adder,
			adder.neg
		])).collect { |deg| Mode(\d).cps(deg) }
	}),
	\timeMul, 0.5, //1 / (Pkey(\range) + 1),
	\delta, Pwhite(1.4, 3.0, inf)
).play;

q.stop;


o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;

o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;


// test move to defs

Fact(\opening) => BP(\op);
Fact(\openingSteps) => BP(\st);

p = BP(\st);

p.listMethods
p.autoRun = false;

p.addMultiSpeed;

p.autoRunMultiSpeed;  // toggles state - do again to stop

p.ffreqCtl.watch.automate({ LFNoise1.kr(1.8).exprange(3000, 6000) }, target: BP(\st).chan.synthgroup, addAction: \addToHead);
p.ffreqCtl.stopWatching.stopAuto;



/**** TODO [#C] Distinguish locomotive themes */



// klankMachine parms references

#[pan, distance], ~xyPat.(parms),
\instrument, Pif((parms[\prob] ? 1).asPattern.coin, instr, \rest),
\delta, parms[\newDelta] ? 0.5,
// exciter time only - note dur is from filtDecay
\time, parms[\excTime] ?? { min(0.15, Pkey(\delta) * 0.7) },
\rate, parms[\rate] ? 1,
\filtFreq, parms[\freq] ? Plazy { |ev| Pn(~kfreqStream.next(ev), inf) },
\filtDecay, Pkey(\delta) * (parms[\timeMul] ? 1),
\filtAmp, parms[\kAmp] ?? { ~kAmpCtl.asMap },
\harm, parms[\harm] ?? {
	Pstutter(Pwhite(3, 6, inf), Pwrand([
		(1..5),
		(1, 3 .. 9),
		Pfuncn({ (1..5) * ({ rrand(0.9, 1.111) } ! 5).put(0, 1) })
	], #[0.4, 0.4, 0.2], inf).collect([_]))
},
\chorusDelay, parms[\chorusDelay] ? 0.03,
\chorusAmt, parms[\chorusAmt] ? 0.02,
\chorusAmps, [parms[\chorusAmps] ? #[1, 1, 1]],
\glrvbamt, parms[\glrvbamt] ? 0.075,
\lcrvbamt, parms[\lcrvbamt] ? 0.035



~clock52 ?? { ~clock52 = TempoClock(52/60) };


SynthDef(\finalRotate, { |outbus,
	radiusSpeed = 0.2, radiusLo = 0.5, radiusHi = 1.0,
	angleSpeedLo = 0.1, angleSpeedHi = 0.6, angleSpeedChRate = 0.7,
	distNear = 5, distFar = 20|
	var	radius = LFDNoise1.kr(radiusSpeed).range(radiusLo, radiusHi),
		angle = Integrator.kr(
			LFDNoise1.kr(angleSpeedChRate).range(angleSpeedLo, angleSpeedHi) * ControlDur.ir
		);
	Out.kr(outbus, [
		cos(angle) * radius,
		(sin(angle) * radius).linlin(-1.0, 1.0, distNear, distFar)
	]);
}).add;



PR(\abstractProcess).clone {
	~event = (eventKey: \polySynthKrBusLock);
	~repeats = inf;
	~requiredKeys = #[vcKey];
	~resetSources = true;

	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
		~ampCtl = GenericGlobalControl(\amp, nil, 0.3, \amp);
	};
	~freeCleanup = { ~ampCtl.free };
	~useGui = { |vp| ~ampCtl => VP(vp) };

	~phraseDur = Pwhite(7.0, 10.0, inf);
	~delta = Pexprand(0.07, 0.6, inf);
	~sustain = Pkey(\phraseDur) - Pseries(0, Pkey(\delta), inf);
	~gate = 0.1;
	~distNear = 50;
	~distFar = 180;
	~ampMul = Plazy({ Pn(~ampCtl.asMap, inf) });
	~mode = \e0;
	~degree = Pseries({ rrand(39, 44) }, Pwrand(#[1, 2, 3], #[0.15, 0.5, 0.35], inf), { rrand(3, 5) });

	~radiusLo = 0.75;
	~radiusSpeed = Pwhite(0.4, 1.4, inf);
	~angleSpeedLo = Prand(#[7.0, -7.0], inf);
	~angleSpeedHi = 14.0 * Pkey(\angleSpeedLo).sign;
	~angleSpeedChRate = Pwhite(0.8, 1.6, inf);
	~lpcEv = Plazy({
		Pbind(
			\instrument, \finalRotate,
			\radiusLo, BPStream(\radiusLo),
			\radiusSpeed, BPStream(\radiusSpeed),
			\angleSpeedLo, BPStream(\angleSpeedLo),
			\angleSpeedHi, BPStream(\angleSpeedHi),
			\angleSpeedChRate, BPStream(\angleSpeedChRate)
		);
	});

	~phrasePat = {
		Pbind(
			\mode, BPStream(\mode, ~resetSources/*, envir: currentEnvironment*/),
			\degree, BPStream(\degree, ~resetSources/*, envir: currentEnvironment*/),
			\freq, Pfunc({ |ev| ev[\mode].asMode.cps(ev[\degree]) }),
			\delta, BPStream(\delta, ~resetSources/*, envir: currentEnvironment*/),
			\sustain, BPStream(\sustain, ~resetSources/*, envir: currentEnvironment*/),
			\gate, BPStream(\gate, ~resetSources/*, envir: currentEnvironment*/),
			\distNear, BPStream(\distNear, ~resetSources/*, envir: currentEnvironment*/),
			\distFar, BPStream(\distFar, ~resetSources/*, envir: currentEnvironment*/),
			\ampMul, BPStream(\ampMul, ~resetSources/*, envir: currentEnvironment*/),
			\lpcEv, BPStream(\lpcEv, ~resetSources/*, envir: currentEnvironment*/),
			\pan, { ~lock.bus.asMap },
			\distance, { ("c" ++ (~lock.bus.index + 1)).asSymbol }
		);
	};
	~asPattern = {
		var	phraseDurPat = Pbind(
			\phraseDur, BPStream(\phraseDur),
			\phraseStartTime, Pfunc({ thisThread.clock.beats })
		);
		PR(\psetp2).copy.prep(
			if(~repeats == inf) {
				PnNilSafe(phraseDurPat, ~repeats)
			} {
				Pfin(~repeats, phraseDurPat)
			},
			Pseq([
				~phrasePat.(),
				Pbind(
					\instrument, \rest,
					\delta, Pfuncn({ |ev| ev[\phraseDur] + ev[\phraseStartTime] - thisThread.clock.beats })
				)
			], 1),
			currentEnvironment  // environment in which 2 patterns will run
		).outerOverridesInner_(false).asPattern
	};

	~bindVoicer = { |vc|
		~vcKey = VC.keys.detect { |key| VC(key).value === vc };
		~event.putAll((
			chan: VC(~vcKey).env.target,
			instrument: VC(~vcKey).v.nodes[0].defname
		));
	};
} => PR(\finalSus);


// reuse of arms axial
// synthdef like airskid, but inharmonic

\addRvbOut.eval(\bellskid, { |noisebuf, nfreq = 440, beats = 4.64,
	chDepth = 0.05, chSpeed = 1.2, chPre = 0.06,
	loffreq = 440, hiffreq = 440, rdecay = 0.01,
	loTime = 0.12, hiTime = 0.22, timeMul = 1,
	amp = 1, pan, sustain = 1|
	var	sig,
		ddelta = Dstutter(2, Dwhite(0.0, 1.0, inf).linexp(0, 1, loTime, hiTime)),
		trig = TDuty.kr(ddelta, 0, ddelta),
		time = Latch.kr(trig, trig) * timeMul;
	sig = WrapInstr("arms.airskid").valueArray([
		noisebuf, nfreq, beats, trig, chDepth, chSpeed, chPre,
		{ |trig, decay|
			var	proportion = TRand.kr(0.02, 0.9, trig); //,
			Env([loffreq, hiffreq, loffreq],
				[proportion, 1 - proportion] * decay, \exp)
		}, rdecay, time, { |sig, rfreq, rdecay|
			Klank.ar(`[
				(1..6) * ({ Rand(0.8, 1.25) } ! 6),
				1 ! 6,
				{ Rand(0.75, 1.25) } ! 6
			], sig, rfreq, 0, rdecay)
		}, amp,
		{ |trig, decay|
			var	proportion = TRand.kr(0.02, 0.9, trig);
			Env([0, 1, 0], [proportion, 1 - proportion] * decay, #[3, -3])
		},
		/*numOverlaps:*/ 3
	]);
	sig = sig * EnvGen.kr(Env.linen(0.1, sustain, 0.1, curve: -2), doneAction: 2);
	Pan2.ar(sig, pan);
}).add;


(
// chan: ,  // FILL IN
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		chan: ~chan,
		isFx: true,
		alwaysReset: true,
 		event: (eventKey: \monoSupport),
		fmtSearch: ~fmtSearch ? "tenor",
		userprep: {
			~fmtKeys = FormantTable.keys.select { |k| k.asString.contains(~fmtSearch) }.asArray;
			~sensCtl = GenericGlobalControl(\sensitivity, nil, 0);
		},
		userfree: {
			~sensCtl.free
		},
		delta: Pexprand(0.1, 0.9, inf), // Pexprand(1.0, 4.0, inf),
		formant: Plazy { Pxrand(~fmtKeys, inf) },
		fadeIn: 12,
		fadeOut: 8,
		recvEventNotify: { |node, event|
			~node = node;
		},
	 	stopCleanup: { ~node.release; ~node = nil; ~makeStreamForKey.(\fmtprotoEvent) },
		objects: (
			fmt: (
				def: SynthDef(\formantfx2, { |inbus, outbus, t_trig = 0, slideTime = 1, gate = 1,
						amp = 1, fadeIn = 5, fadeOut = 5|
					var	ffreqs = NamedControl.kr(\ffreqs, Array.series(5, 400, 400)),
						amps = NamedControl.kr(\amps, 1 ! 5),
						qs = NamedControl.kr(\qs, 0.1 ! 5),
						sig = In.ar(inbus, 2), sig2,
						wet = Linen.kr(gate, fadeIn, 1, fadeOut, doneAction: 2);
					ffreqs = ffreqs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
					amps = amps.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
					qs = qs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
					sig2 = BBandPass.ar(sig, ffreqs, qs, amps).sum * amp;
					sig = XFade2.ar(sig, sig2, wet.madd(2, -1));
					ReplaceOut.ar(outbus, Limiter.ar(sig));
				}),
				args: [
					protoEvent: Pseq([\singleSynthPlayNotify, Pn(\singleSynthTrigger, inf)]),
					#[ffreqs, amps, qs], Pnsym(BPStream(\formant), FormantTable),
					ffreqs: Pkey(\ffreqs) * Pexprand(0.95, 0.95.reciprocal, inf).clump(5),
					trig: 1,
					slideTime: Pkey(\delta) * Pwhite(0.4, 0.8, inf),
					inbus: Plazy { Pn(~chan.inbus, inf) },
					node: Pfunc { ~node ? 0 },
					sustain: inf,
					amp: 12.5.dbamp,
					fadeIn: BPStream(\fadeIn),
					fadeOut: BPStream(\fadeOut)
				]
			)
		)
	));
}, type: \bp) => Fact(\formantfx2);


(make: { |name|
	BP(name).free;
	PR(\basicBufferPlayer).chuck(BP(name), nil, (
		bufPaths: (topEnvironment[\sampleDir] +/+ "head/udu*").pathMatch,
		master: ~master,
		inChannels: 2,
		postMCCreation: {
			~shapebuf = Buffer.sendCollection(s,
				(Pseries.fromEndpoints(-1.0, 1.0, 512).asStream.all * 6.1887796806608).tanh
				.as(Signal).asWavetable, wait: 0.05
			);
			~event.proto = topEnvironment[\rvbEvent].proto;
			~ampCtl = GenericGlobalControl(\amp, nil, 0.5, \amp);
			~event[\chan] = ~chan;		
		},
		free: {
			[~shapebuf, ~ampCtl].free;
		},
		useGui: { |vp| ~ampCtl => VP(vp) },
		def: \bufGrainPanKlShpDist,
		buffer: Plazy({ Prand(~buffers, inf) }),
		bufnum: Pfunc({ |ev| ev[\buffer].bufnum }),
		time: Pfunc({ |ev| ev[\buffer].duration / ev[\rate] }),
		filtFreq: exprand(300, 900),
		filtAttack: 0.002,
		decayMap: Env(#[0.01, 0.18], #[1], 7).asArray,
		filtDecay: Pwhite(0, 1, inf).collect { |dec| ~decayMap.envAt(dec) },
		harm: (1, 3 .. 9) * Pexprand(0.9, 0.111, inf).clump(5),
		chorusAmps: #[0, 0, 0],
		distance: Pwhite(5.0, 18.0, inf),
		pan: Pwhite(-1.0, 1.0, inf),
		amp: Pexprand(0.4, 0.9, inf),
		rate: Pexprand(0.8, 3.3, inf),
		delta: Pseq([
			Pexprand(0.05, 0.2, { rrand(3, 11) }),
			Pwhite(0.3, 0.7, 1)
		], inf),
		asPattern: {
			Pbind(
				\instrument, BPStream(\def),
				\buffer, BPStream(\buffer),
				\bufnum, BPStream(\bufnum),
				\rate, BPStream(\rate),
				\time, BPStream(\time),
				\filtFreq, BPStream(\filtFreq),
				\filtAttack, BPStream(\filtAttack),
				\filtDecay, BPStream(\filtDecay),
				\harm, BPStream(\harm),
				\chorusAmps, BPStream(\chorusAmps),
				\shapebuf, ~shapebuf,
				\ampMap, ~ampCtl.asMap,
				\delta, BPStream(\delta),
				\distance, BPStream(\distance),
				\pan, BPStream(\pan)
			)
		}
	));
	0 => BP(name);
}, type: \bp) => Fact(\messyDrums);



// melody over P4
MIDIRecBuf(\bodymel, [
	#[64, 66,  69, 60,  58, 65, 63, 70, 72, 69,
		74, 67,  70, 60,  58, 65, 63, 66, 57, 59
	],
	#[1, 3,  1, 3,  1, 2, 1, 1, 1, 3,
		1, 3,  1, 3,  1, 1, 1, 2, 3, 16
	],
	#[1.1, 2.9,  1.1, 2.9,  1.1, 1.9, 1.1, 1.1, 1.1, 2.9,
		1.1, 2.9,  1.1, 2.9,  1.1, 1.1, 1.1, 1.9, 3.1, 16
	],
	0.2
].asNotes, properties: (type: \mel)) => MBM(0);


(make: { |name|
	PR(\mel1).chuck(BP(name), nil, (
		prep: {
			~posBus = Bus.control(s, 2);
			~panCtl = GenericGlobalControl(\pan, ~posBus.index.asBus(\control), 0, \bipolar);
			~distanceCtl = GenericGlobalControl(\distance, (~posBus.index+1).asBus(\control), 0, #[5, 20]);
			~ampCtl = GenericGlobalControl(\amp, nil, 2.25, #[0.1, 10, \exp]);
			~event.proto = topEnvironment[\rvbEvent].proto.copy.put(\glrvbmc, topEnvironment[\cRvbMc]);
		},
		freeCleanup: {
			[~posBus, ~panCtl, ~distanceCtl, ~ampCtl].free;
		},
		useGui: { |vp| [~panCtl, ~distanceCtl, ~ampCtl].do { |gc| gc => VP(vp) }	},
		preparePlay: {
			var	lo;
			~rotSynth ?? {
				~rotSynth = Synth(\finalRotate, [
					\outbus, ~posBus,
					\radiusLo, 0.75,
					\radiusSpeed, rrand(0.4, 1.4),
					\angleSpeedLo, lo = #[2.0, -2.0].choose,
					\angleSpeedHi, 5.5 * lo.sign,
					\angleSpeedChRate, rrand(0.8, 1.6)
				], ~event[\voicer].target, \addToHead);
			}
		},
		stopCleanup: {
			~rotSynth !? {
				~rotSynth.free;
				~rotSynth = nil;
			}
		},
		asPattern: { 
			Pbind(
				#[note, delta], ~asNotePattern.value.collect({ |n| [n, n.dur] }),
				\distance, ~distanceCtl.asMap,
				\pan, ~panCtl.asMap,
				\ampMul, ~ampCtl.asMap
			);
		}
	));
	0 => BP(name);
	MBM(0)[\bodymel] => BP(name);
}, type: \bp) => Fact(\bodymel);



\addRvbOut.eval(\lowdrumslide, { |outbus, bufnum, attackTime = 0.1, rate = 1, start = 0,
	freq = 110, time,
	preamp = 1, amp = 1, xover = 400, pan, ampMap = 1|
	var	atk = PlayBuf.ar(1, bufnum, rate, 1, start, loop: 0)
			* EnvGen.kr(Env.linen(0.01, attackTime, 0.1)) * amp,
		freqenv = NamedControl.kr(\freqenv, (0!20).overWrite(Env.one.asArray)),
		body = SinOsc.ar(freq * EnvGen.kr(freqenv), 0.5pi, preamp).tanh * amp,
		ampenv = NamedControl.kr(\ampenv, (0!20).overWrite(Env(#[0, 1, 0.75, 0], #[0.003, 0.1, 0.887]).asArray)),
		eg = EnvGen.kr(ampenv, timeScale: time, doneAction: 2),
		hpf = HPF.ar(body, xover),
		chorus = DelayL.ar(hpf, 0.005, SinOsc.kr(Rand(0.15, 0.25), 0, Rand(0.001, 0.002), Rand(0.002, 0.003)));
	body = (body-hpf) + hpf + chorus;
	Out.ar(outbus, Pan2.ar((atk + body), pan, eg * ampMap));
}).add;



{	var	avail, playBar = ~playBar.next > 0;
	if(playBar) {
		~amps = ~ampBase.copy;
		avail = (7..15).scramble;
	} {
		~amps = (0!16);
		avail = (3..15).scramble;
	};
	~times = (0 ! 16).put(0, 0.4).put(3, 0.2);
	rrand(0, 4).do { |i|
		~amps[avail[i]] = exprand(0.3, 0.8);
		~times[avail[i]] = exprand(0.06, 0.12);
	};
	~argPairs = ~origArgPairs.copy.put(1, playBar.not.binaryValue);
	\shrinkKeys.eval;
} => Func(\lowdrumgen);

(make: { |name|
	BP(name).free;
	PR(\bufPerc).chuck(BP(name), nil, (
		bufPaths: [topEnvironment[\sampleDir] +/+ "head/uduSLAP1.wav"],
		bufCoords: #[[300, -1]],
		alwaysReset: true,
		master: topEnvironment[\master],
		glrvbmc: topEnvironment[\cRvbMc],
		lcrvbmc: topEnvironment[\lcrvbmc],
		inChannels: 2,
		def: \lowdrumslide,
		postMCCreation: {
			~event.proto = topEnvironment[\rvbEvent].proto;
			~event.putAll((glrvbamt: 0.2, lcrvbamt: 0.1));
			[~glrvbmc, ~lcrvbmc].do { |mc| mc.tryPerform(\receivesSignalFrom, ~chan) };
			~distanceCtl = GenericGlobalControl(\distance, nil, 5, #[5, 20]);
			~ampCtl = GenericGlobalControl(\amp, nil, -6.dbamp, \amp);
		},
		free: { [~distanceCtl, ~ampCtl].free },
		pbindPreAction: \lowdrumgen,
		amps: #[0],
		rates: 0.46,
		ampBase: #[1, 0, 0, 1] ++ (0!12),
		playBar: Pseq(#[1, 0], inf).asStream,
		reset: { ~playBar.reset },
		usedKeys: #[times],
		origArgPairs: [
			drop: 0,
			freq: Pseq([40.midicps, Pn(50.midicps, inf)], 1).drop({ |ev| ev[\drop] }),
			freqenv: Pseq([Pfuncn({ ~slideEnv }), Pn(`(Env.one), inf)], 1).drop({ |ev| ev[\drop] }),
			preamp: 4.23,
			distance: Plazy({ Pn(~distanceCtl.asMap, inf) }),
			ampMap: Plazy({ Pn(~ampCtl.asMap, inf) })
		],
		slideEnv: `(Env(#[1, 1, 3], #[0.2, 0.2], 6))
	));
	topEnvironment[\clock52] => BP(name);
}, type: \bp) => Fact(\lowdrum);


{	var	acc = ~accentOptions.choose, avail;
	~amps = ~ampBase.copy;
	~bufs = ~ampBase.copy;
	~pans = ~ampBase.copy;
	avail = (0..31);
	acc.do { |i|
		~amps[i] = 1;
		~bufs[i] = ~buffers.size.rand;
		~pans[i] = 0;
		avail.takeAt(i);
	};
	avail = avail.scramble;
	(~densityCtl.value + 7.rand).do { |i|
		~amps[avail[i]] = exprand(0.3, 0.8);
		~bufs[i] = ~buffers.size.rand;
		~pans[i] = 0.7.rand2;
	};		
	\shrinkKeys.eval;
} => Func(\hidrumgen);


(make: { |name|
	BP(name).free;
	PR(\bufPerc).chuck(BP(name), nil, (
		bufPaths: (topEnvironment[\sampleDir] +/+ "head/*FING*.wav").pathMatch,
		alwaysReset: true,
		master: topEnvironment[\master],
		glrvbmc: topEnvironment[\cRvbMc],
		lcrvbmc: topEnvironment[\lcrvbmc],
		inChannels: 2,
		def: \bufGrainPanFiltDist,
		pbindPreAction: \hidrumgen,
		postMCCreation: {
			~event.proto = topEnvironment[\rvbEvent].proto;
			~event.putAll((glrvbamt: 0.2, lcrvbamt: 0.1));
			[~glrvbmc, ~lcrvbmc].do { |mc| mc.tryPerform(\receivesSignalFrom, ~chan) };
			~distanceCtl = GenericGlobalControl(\distance, nil, 5, #[5, 20]);
			~densityCtl = GenericGlobalControl(\density, nil, 1, #[1, 12, \lin, 1]);
			~ampCtl = GenericGlobalControl(\amp, nil, 1, \amp);
		},
		free: { [~distanceCtl, ~densityCtl, ~ampCtl].free },
		amps: #[0],
		divCycle: 0.125,
		ampBase: (0!32),
		accentOptions: #[[8], [18, 24], [12]],
		usedKeys: #[bufs, pans],
		argPairs: [
			distance: Plazy({ Pn(~distanceCtl.asMap, inf) }),
			ffreq: 18000,
			pan: Plazy({ Pseq(~pans, 1) }),
			ampMap: Plazy({ Pn(~ampCtl.asMap, inf) })
		]
	));
	topEnvironment[\clock52] => BP(name);
}, type: \bp) => Fact(\hidrum);



PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);

	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
		~event.putAll((glrvbamt: 0.2, lcrvbamt: 0.1));
		[~glrvbmc, ~lcrvbmc].do { |mc| mc.tryPerform(\receivesSignalFrom, ~chan) };
		~distanceCtl = GenericGlobalControl(\distance, nil, 5, #[5, 20]);
		~densityCtl = GenericGlobalControl(\density, nil, 1, #[1, 5, \lin, 1]);
		~ampCtl = GenericGlobalControl(\amp, nil, -7.5.dbamp, \amp);
	};
	~free = { [~distanceCtl, ~densityCtl, ~ampCtl].free };

	~mode = \d;
	~mod_lev = Pkey(\gate).linlin(0.2, 0.8, 1.2, 3.0); // Pexprand(1.5, 3.0, inf);
	~mod_ratio = 3;
	~pitchBase = #[40, 33, 31].mapMode(\d);
	~timeptBase = #[0, 0.75, 1.5];
	~lengthBase = (0.25!3);
	~ampBase = #[1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0];
	~calcBar = \simpleBassLine; // \makeBassNotes;
	~usedKeys = #[freqs, durs, lengths, gates];

	~asPattern = {
		PnNilSafe(Plazy({
			~calcBar.eval;
			Pbind(
				\mode, BPStream(\mode),
				\freq, Pseq(~freqs, 1),
				// durs should always end with 4
				\dur, Pdelta(Pseq(~durs ++ #[4], 1), 4),
				\length, Pseq(~lengths, 1),
				\gate, Pseq(~gates, 1),
				\mod_lev, BPStream(\mod_lev),
				\mod_ratio, BPStream(\mod_ratio),
				\attackTimeScale, 0.1,
				\decayTimeScale, 0.5,
				\distance, ~distanceCtl.asMap,
				\finalAmp, ~ampCtl.asMap
			)
		}), inf);
	};
} => PR(\bassline);


{	var	avail, last = 16;
	~amps = ~ampBase.copy;
	~freqs = ~pitchBase.copy;
	~durs = ~timeptBase.copy;
	~lengths = ~lengthBase.copy;
	~gates = 0.8 ! 3;
	\expandKeys.eval;
	
	avail = ~amps.collectIndicesOfItem(0).scramble;
	(~densityCtl.value + 3.rand).do { |i|
		i = avail[i];
		~amps[i] = 1;
		~freqs[i] = rrand(15, 26);
		~durs[i] = i * 0.25;
		~gates[i] = exprand(0.4, 0.75);
		~lengths[i] = 0.15;
	};
	~lengths.reverseDo { |len, i|
		if(len > 0) {
			i = 15-i;
			if(0.15.coin) {
				~lengths[i] = rrand(0.1, (last - i) * 0.25 - 0.15);
			};
			last = i;
		};
	};
	
	\shrinkKeys.eval;
} => Func(\makeBassNotes);

{	var	avail;
	~amps = ~ampBase;
	~freqs = ~pitchBase;
	~durs = ~timeptBase;
	~lengths = ~lengthBase;
	~gates = 0.8 ! 3;
} => Func(\simpleBassLine);




(
keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;

	PR(\basicBufferPlayer).chuck(BP(name), nil, (
		event: (
			eventKey: \polySynthPlayerData,
			instrument: \bufGrainPanKlankDist,
			vizPath: #[perc]
		),
		soundID: Pseries(0, 1, inf),
		alwaysReset: true,

		bufPaths: [topEnvironment[\feetdir].dirname +/+ "samples/feet/58454_sinatra314_footsteps_wooden_floor_loop.wav"],

		inChannels: 2,
		master: ~master,
		glrvbmc: ~glrvbmc,
		lcrvbmc: ~lcrvbmc,
		initAmp: 1,

		def: \bufGrainPanKlankDist,
		delta: Pwrand(#[0.5, 1.0], #[0.95, 0.05], inf),
		time: 0.15,
		rate: 1,
		start: Pfunc({ |ev| ~pt[ev[\ptIndex]] * ~buffers[0].sampleRate }),
		amp: 6.dbamp,
		distance: Pseg(
			Ppatlace([Pwhite(14.0, 20.0, inf), Pwhite(7.0, 10.0, inf)], inf),
			Pexprand(2.0, 7.0, inf),
			\lin
		),
		pan: Pseg(
			Pwhite(0.75, 1.0, inf) * Pseq(#[-1, 1], inf, { 2.rand }),
			Pexprand(2.0, 7.0, inf),
			\lin
		),
		ffreq: 14000,
		ptIndex: Pwhite(0, Pfunc({ ~pt.size - 1 }), inf).clump(3),
		bufIndex: 0,
		mode: Pwrand(#[d0, e0], #[0.8, 0.2], inf),
		filtAmp: 0,
		filtDegree: Pwhite(39, 49, inf),
		filtFreq: Pfunc({ |ev| ev[\mode].asMode.cps(ev[\filtDegree]) }),
		filtDecay: 0.011,

		superPattern: PR(\basicBufferPlayer).v[\asPattern],
		asPattern: {
			Pbind(
				\distance, BPStream(\distance),
				\pan, BPStream(\pan),
				\ffreq, BPStream(\ffreq),
				\chorusAmps, #[[0, 0, 0]],
				\mode, BPStream(\mode),
				\filtAmp, BPStream(\filtAmp),
				\filtDegree, BPStream(\filtDegree),
				\filtFreq, BPStream(\filtFreq),
				\filtDecay, BPStream(\filtDecay)
			)
			<>
			~superPattern.()
			<>
			Pbind(\ptIndex, BPStream(\ptIndex))
		},

		postMCCreation: { |chan|
			[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\receivesSignalFrom, ~chan));

			~chan.playfx(Instr("busfx.limiter"), [0, 2, 0.99, 0.05]);

			~ampCtl = GenericGlobalControl(\amp, nil, ~initAmp, \amp);
			~kAmpCtl = GenericGlobalControl(\kAmp, nil, 1, \amp);
			~ffreqCtl = GenericGlobalControl(\ffreq, nil, 18000, \freq);
			~event.putAll((
				// just in case reverb channels don't exist,
				// push them to hw input buses (to suppress output)
				glrvbout: ~glrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
				lcrvbout: ~lcrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
				chan: ~chan,
				ampMap: ~ampCtl.asMap
			));
			~readLabels.();
		},
		useGui: { |vpi| [~ampCtl, ~kAmpCtl, ~ffreqCtl].do { |gc| gc => VP(vpi) } },
		free: {
			[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\stopsReceivingFrom, ~chan));
			[~ampCtl, ~kAmpCtl, ~ffreqCtl, ~shapebuf].free;
		},
		processLabels: PR(\steps1).v[\processLabels],
		readLabels: PR(\steps1).v[\readLabels],
		labelPath: {
			~bufPaths[0].dirname
				+/+ ~bufPaths[0].basename[.. ~bufPaths[0].basename.indexOf($_)]
				++ "labels3.txt"
		}
	));
	topEnvironment[\clock52] => BP(name);
	// synths need to run just ahead of the beat to sound on time
	#[1, -0.07] => BP(name);
}, type: \bp) => Fact(\bodySteps);


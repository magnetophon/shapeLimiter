declare author "Bart Brouns";
declare license "GPLv3";
declare name "shaperLimiter";
import("stdfaust.lib");


// power = 4;
power = 11;
// power = 13;

process =
  limTest;

testRouting =
  (
    ro.interleave(power,2)
    :
    par(i, power, (FB~(_,!):(!,_)))
    :minOfN(power)
  )
  ~(_<:si.bus(power))
;

FB(prev,prev2,x) = prev+1,prev+x;

// TODO: sprecial state for going up and attacking at the same time: shorter keepDirection
// make speed dependant on distance to target trough min(0) or max(0)
//
// crossfade from old-dir to newval: faster if speed-difference is small

limTest =
  testSignal*checkbox("signal")
  : ParalelOpsOfPow2(min,power)
  : par(i, power+1, _@restDelay(power,i) )
  :
  (
    ro.interleave(power+1,3)
    :
    par(i, power+1, (rampFromTo(i)))
    : ro.interleave(2,power+1)
    :(minOfN(power+1),minOfN(power+1))
  )
  ~((_<:si.bus((power+1))),(_<:si.bus((power+1))))
   // : ParalelOpsOfPow2(min,power) : (par(i, power, !),_)
   // : ((rampFromTo(power)~(_,_)):(!,_))
   // : ((rampFromTo(power)~(_,_,_)):(_,_,_))
  ,testSignal@(pow2(power)-1)
with {
  rampFromTo(i,prevVal,linPrev,target) =
    (it.interpolate_linear(
        ramp(pow2(i),trig):shaper
       ,keepDirection,to)
     : slowDownNearTarget
       // <: (_,overShootShaper)
    )
    // , target
  , linCur
    // ,attacking
    // , 1
    // , linCur
    // ,to
    // ,currentDirection
    // , slowDownAmount
    // ,proposedDirection
    // , state
    // , (ramp(pow2(i),trig):shaper)
  with {
  // ramp(n,reset) = ((select2(reset*((_==1)|(_==0)),_+(1/n):min(1),1/n))+(n<1):min(1))~(_<:(_,_,_));
  ramp(n,reset) = ((select2(reset,_+(1/n):min(1),1/n))+(n<1):min(1))~_;
  keepDirection = ((_+oldDirection)~(_*(1-trig)))+from;
  oldDirection =
    ((prevVal-prevVal'):ba.sAndH(trig));
  // currentDirection = (to-from);
  currentDirection = (linPrev - linPrev')*pow2(i);
  // / pow2(i);
  // proposedDirection = (linCur - linCur')*pow2(i);
  proposedDirection = (target - linPrev );
  // / pow2(i);
  from = prevVal:ba.sAndH(trig);
  linFrom = linPrev:ba.sAndH(trig);
  to = target:ba.sAndH(trig);
  // trig = (target!=target');
  trig =
    // proposedDirection < currentDirection
    // | (currentDirection == 0)
    select2(attacking
           , (
             (proposedDirection < (currentDirection*(pow2(i)+hslider("offset", 0, -pow2(power), pow2(power), 1))/pow2(i) ))
             | (currentDirection == 0)
           )
  , proposedDirection < currentDirection
)
    // | impulse // TODO: replace with os.impulse:
    | button("reset")
    // | ((prevVal == prevVal'):ba.impulsify)
  ;
  attacking = target < linPrev;
  impulse = 1-1';
  // trig = (target<target') | ((prevRamp == 1) & (target>target')) ;
  // trig = (target<target') | ((prevRamp == 1) & (min(target,target@pow2(i))>target')) ;
  // trig = (target<target') | ((prevRamp == 1) & (target>min(target',prevVal))) ;
  state = prevVal>to;
  linCur =
    it.interpolate_linear(
      ramp(pow2(i),trig)
     ,linFrom,to);
  slowDownNearTarget(x) =
    select2(checkbox("slowdown enable")
           , x
           , (x-prevVal) *(slowDownAmount) + prevVal);
  // slowDownNearTarget(x) = (x-x') * slowDownAmount + x';
  slowDownAmount =
    // 1
    (1-(1-normalisedDelta :pow(hslider("slowDown", 0.5, 0.00001, 30, 0.001))))
    *const:min(1):max(0)
                  // :hbargraph("slow", 0, 1)
  ;
  const = hslider("const", 1, 0, 10, 0.001);
  // delta = (prevVal-(testSignal@pow2(i)));
  delta = (prevVal-target);
  deltaTrig = abs(delta)>abs(delta');
  normalisedDelta = delta:abs
  ;
  // / (delta:ba.sAndH(trig));
  // normalisedDelta = delta / (delta:ba.sAndH(deltaTrig));
  overShootShaper(x) =
    select2(checkbox("overs"),x,
            select2(to == 0,  max(x/to,sin(ma.PI*(x/to-0.5)))*to, x)
           );
};
  // minOfN(0) = !;
  // minOfN(1) = _;
  // minOfN(N) = seq(i, N-1, min,myBus(N-i-2));
  // delays(N) = (par(i, N-1, (_@restDelay(N,i))),_);
  // restDelay(N,i) = pow2(N)-pow2(i);
};

minOfN(0) = !;
            minOfN(1) = _;
minOfN(N) = seq(i, N-1, min,myBus(N-i-2));
delays(N) = (par(i, N-1, (_@restDelay(N,i))),_);
restDelay(N,i) = pow2(N)-pow2(i);

SOFTenvelope = it.interpolate_linear(theRamp,keepDirection,to(state));



ParalelOpsOfPow2(op,power) =
  seq(i, power,
      myBus(i)
      ,
        ( _<:
          (
            _
          , ((_,_@pow2(i)):op)
          )
        )
     );


pow2(i) = 1<<i;
myBus(0) = 0:!;
           myBus(i) = si.bus(i);




// https://www.desmos.com/calculator/oufrdvzdcv
// based on:
// Adjustable Sigmoid Curve (S-Curve)
// https://math.stackexchange.com/questions/459872/adjustable-sigmoid-curve-s-curve-from-0-0-to-1-1
// https://www.desmos.com/calculator/tswgrnoosy

shaper(x) = nts3(sin(ma.PI*(x-0.5)),k1,k2,k3)*0.5+0.5;
// shaper(x,k1,k2,k3) = nts3(sin(ma.PI*(x-0.5)),k1,k2,k3);
nts3(x,k1,k2,k3) = fd(nts(fc(nts(fd(nts(fc(x),k1)),k2)),k3))
with {
  nts(x,k) = (x-x*k)/(k-abs(x)*2*k+1);
  fc(x) = x*0.5 + 0.5;
  fd(x) = 2*x-1;
};

// ntsSin(x,k1,k2,k3) =
// .99 = .956

// limiter shaper:
// https://www.desmos.com/calculator/hkqvmomfzp

k1 = hslider("k1", 0, -1, 1, 0.001):si.smoo;
k2 = hslider("k2", 0, -1, 1, 0.001):si.smoo;
k3 = hslider("k3", 0, -1, 1, 0.001):si.smoo;

blockRate = hslider("[0]block rate", 0.001, 0, 10, 0.001)*100000;
noiseLevel = hslider("[1]noise level", 0, 0, 1, 0.01);
noiseRate = hslider("[2]noise rate", 20, 10, 20000, 10);

totalLatency = pow2(power);
testSignal =
  vgroup("testSignal",
         no.lfnoise0(blockRate / totalLatency  * (1+((no.lfnoise(blockRate/totalLatency):pow(8):abs)*totalLatency*hslider("blockVar", 0, 0, 1, 0.001)) ))
         :pow(3)*(1-noiseLevel) +(no.lfnoise(noiseRate):pow(3) *noiseLevel):min(0)) ;

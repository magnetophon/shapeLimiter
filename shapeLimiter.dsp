declare author "Bart Brouns";
declare license "GPLv3";
declare name "shaperLimiter";
import("stdfaust.lib");


// power = 4;
power = 13;

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

limTest =
  testSignal
  // : ParalelOpsOfPow2(min,power)
  // : par(i, power+1, _@restDelay(power,i) )
  // :
  // (
  // ro.interleave(power+1,2)
  // :
  // par(i, power+1, (rampFromTo(i+1)~(_,!):(!,_)))
  // :minOfN(power+1)
  // )
  // ~(_<:si.bus(power+1))
  : (rampFromTo(power)~(_,_,!))
 ,testSignal@(pow2(power)-1)
with {
  rampFromTo(i,prevRamp,prevVal,target) =
    (ramp(pow2(i),trig))
  , it.interpolate_linear(
      ramp(pow2(i),trig):shaper
     ,keepDirection,to)
  , state
    // , (ramp(pow2(i),trig):shaper)
  with {
  ramp(n,reset) = (select2(reset,_+(1/n):min(1),1/n)~_)+(n<1):min(1);
  // trig = (target<target') | ((prevRamp == 1) & (target>target'))@pow2(i) ;
  trig = (target<target') | ((prevRamp == 1) & (target>target')) ;
  keepDirection = ((_+oldDirection)~(_*(1-trig)))+from;
  oldDirection =
    ((prevVal-prevVal'):ba.sAndH(trig));
  from = prevVal:ba.sAndH(trig);
  to = target:ba.sAndH(trig);
  state = prevVal>to;
  // state = prevVal<to;
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

blockRate = hslider("[0]block rate", 0.001, 0, 1, 0.001)*100000;
noiseLevel = hslider("[1]noise level", 0, 0, 1, 0.01);
noiseRate = hslider("[2]noise rate", 20, 10, 20000, 10);

totalLatency = pow2(power);
testSignal =
  vgroup("testSignal",
         no.lfnoise0(blockRate / totalLatency  * (1+((no.lfnoise(blockRate/totalLatency):pow(8):abs)*totalLatency*hslider("blockVar", 0, 0, 1, 0.001)) ))
         :pow(3)*(1-noiseLevel) +(no.lfnoise(noiseRate):pow(3) *noiseLevel):min(0)) ;

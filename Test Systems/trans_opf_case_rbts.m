function [baseMVA,bus,busPmax,busPmin,busQmax,busQmin,busPG,busQG,gen,branch, PBase ,PFBase,busLoadImportant,w_gen] = data_RBTS
%RBTS_DATA 此处显示有关此函数的摘要
%   此处显示详细说明
%% MATPOWER Case Format : Version 2
version = '2';

[PQ, PV, REF, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM, ...
	VA, BASE_KV, VMAX, VMIN, PGMAX,PGMIN,QGMAX,QGMIN,PG,QG,LOLP,LOLE,LOLF,LOLD,EDNS,EENS,...
    LAM_P,LAM_Q,MU_VMAX,MU_VMIN,MU_PMAX,MU_PMIN,MU_QMAX,MU_QMIN] = idx_bus;
[GEN_BUS, GEN_PMAX, GEN_PMIN, GEN_QMAX, GEN_QMIN, GEN_STATUS, ...
	GEN_LAMDA,GEN_MTTF,GEN_PG,GEN_QG,GEN_PFAILURE] = idx_gen;
[F_BUS, T_BUS, BR_R, BR_X, BR_B, RATE, TAP, SHIFT_ANGLE, BR_STATUS, BR_LAMDA,...
        BR_MTTF,TCSC_X, BR_PFAILURE, PF, QF, PT, QT, MU_SF, MU_ST, KT_MAXANGLE_TPST,KT_MINANGLE_TPST,KT_MAX_X_TCSC,KT_MIN_X_TCSC] = idx_brch;
[NEWTON,FDFP_XB,FDFP_BX,DCPF] = idx_powerflow;

%%-----  Power Flow Data  -----%%
%% system MVA base
baseMVA = 100;
%% bus data
%   Bus Data Format
%       1   bus number (1 to 29997)
%       2   bus type
%               PQ bus          = 1
%               PV bus          = 2
%               reference bus   = 3
%       3   Pd, real power demand (MW)
%       4   Qd, reactive power demand (MVAR)
%       5   Gs, shunt conductance (MW (demanded?) at V = 1.0 p.u.)
%       6   Bs, shunt susceptance (MVAR (injected?) at V = 1.0 p.u.)
%       7   area number, 1-100
%       8   Vm, voltage magnitude (p.u.)
%       9   Va, voltage angle (degrees)
%       10  baseKV, base voltage (kV)
%       11  maxVm, maximum voltage magnitude (p.u.)
%       12  minVm, minimum voltage magnitude (p.u.)
bus = [
	1	3	0.00000	0.00000	0.00000	0.00000	1	1.0500	0.0000	230.0000    1	1.0500	0.9700;
	2	2	20.0000	4.00000	0.00000	0.00000	1	1.0500	0.0000	230.0000    1	1.0500	0.9700;
	3	1	85.0000	17.0000	0.00000	0.00000	1	1.0000	0.0000	230.0000    1	1.0500	0.9700;
	4	1	40.0000	8.00000	0.00000	0.00000	1	1.0000	0.0000	230.0000    1	1.0500	0.9700;
	5	1	20.0000	4.0000	0.00000	0.00000	1	1.0000	0.0000	230.0000    1	1.0500	0.9700;
	6	1	20.0000	4.00000	0.00000	0.00000	1	1.0000	0.0000	230.0000    1	1.0500	0.9700;
];

busLoadImportant = [
	1   1.0000  1.0000  1.0000;
	2	1.0000  1.0000  1.0000;
	3	1.0000  1.0000  1.0000;
	4	1.0000  1.0000  1.0000;
	5	1.0000  1.0000  1.0000;
	6	1.0000  1.0000  1.0000;
];

%% generator data
%   Generator Data Format
%       1   bus number
%       2   Pmax, maximum real power output (MW)
%       3   Pmin, minimum real power output (MW)
%       4   Qmax, maximum reactive power output (MVAR)
%       5   Qmin, minimum reactive power output (MVAR)
%       6   status, 1 - machine in service, 0 - machine out of service
%       7   Lamda, Failure Rate
%       8   MTTF, Repair duration
%       9   PG,original real power output (MW)
%       10  QG,original reactive power output (MVAR)
%       11   PFailure, Probability of Failure
gen = [    
	1	40.00000	0.0000	17.00000	-15.00000	1	100	1    40	0	0	0	0	0	0	0	0	0	0	0	0;
   	1	10.00000	0.0000	7.000000	0.0000000	1	100	1    10	0	0	0	0	0	0	0	0	0	0	0	0;
    1	20.00000	0.0000	12.00000	-7.000000	1	100	1    20	0	0	0	0	0	0	0	0	0	0	0	0;
    1	40.00000	0.0000	17.00000	-15.00000	1	100	1    40	0	0	0	0	0	0	0	0	0	0	0	0;
    2	5.000000	0.0000	5.000000	0.0000000	1	100	1    5	0	0	0	0	0	0	0	0	0	0	0	0;
    2	5.000000	0.0000	5.000000	0.0000000	1	100	1    5	0	0	0	0	0	0	0	0	0	0	0	0;
    2	20.00000	0.0000	12.00000	-7.000000	1	100	1    20	0	0	0	0	0	0	0	0	0	0	0	0;
    2	20.00000	0.0000	12.00000	-7.000000	1	100	1    20	0	0	0	0	0	0	0	0	0	0	0	0;
    2	20.00000	0.0000	12.00000	-7.000000	1	100	1    20	0	0	0	0	0	0	0	0	0	0	0	0;
    2	20.00000	0.0000	12.00000	-7.000000	1	100	1    20	0	0	0	0	0	0	0	0	0	0	0	0;
    2	40.00000	0.0000	17.00000	-15.00000	1	100	1    40	0	0	0	0	0	0	0	0	0	0	0	0;
];
%% branch data
%   Branch Data Format
%       1   f, from bus number
%       2   t, to bus number
%       3   r, resistance (p.u.)
%       4   x, reactance (p.u.)
%       5   b, total line charging susceptance (p.u.)
%       6   rate, MVA rating 
%       7   ratio, transformer off nominal turns ratio ( = 0 for lines )
%           (taps at 'from' bus, impedance at 'to' bus, i.e. ratio = Vf / Vt)
%       8   angle, transformer phase shift angle (degrees)
%       9   branch status, 1 - in service, 0 - out of service
%       10  Lamda, Failure Rate
%       11  MTTF, Repair duration
%       12  TCSC setting
%       13  PFailure, Probability of Failure
branch = [
    1	2	0.0912	0.4800	0.0564	71.00000	71.000000	71.000000	0	0	1	-360	360;
	2	4	0.1140	0.6000	0.0704	71.00000	71.000000	71.000000	0	0	1	-360	360;
    2	4	0.1140	0.6000	0.0704	71.00000	71.000000	71.000000	0	0	1	-360	360;
    1	3	0.0342	0.1800	0.0212	85.00000	85.000000	85.000000	0	0	1	-360	360;
    1	3	0.0342	0.1800	0.0212	85.00000	85.000000	85.000000	0	0	1	-360	360;
	3	4	0.0228	0.1200	0.0142	71.00000	71.000000	71.000000	0	0	1	-360	360;
	3	5	0.0228	0.1200	0.0142	71.00000	71.000000	71.000000	0	0	1	-360	360;
	4	5	0.0228	0.1200	0.0142	71.00000	71.000000	71.000000	0	0	1	-360	360;
   	5	6	0.0228	0.1200	0.0142	71.00000	71.000000	71.000000	0	0	1	-360	360;
];
%%-----  OPF Data  -----%%
%% generator cost data
%	1	startup	shutdown	n	x1	y1	...	xn	yn
%	2	startup	shutdown	n	c(n-1)	...	c0
gencost = [
    2	1500	0	3	0.11	5	150;
    2	2000	0	3	0.085	1.2	600;
    2	3000	0	3	0.1225	1	335;
    2	1500	0	3	0.11	5	150;
    2	2000	0	3	0.085	1.2	600;
    2	3000	0	3	0.1225	1	335;
    2	1500	0	3	0.11	5	150;
    2	2000	0	3	0.085	1.2	600;
    2	3000	0	3	0.1225	1	335;
    2	1500	0	3	0.11	5	150;
    2	2000	0	3	0.085	1.2	600;
];

rate = 1.00;
bus(:,3) = rate.*bus(:,3);
bus(:,4) = rate.*bus(:,4);
gen(:,2) = rate.*gen(:,2);
gen(:,3) = rate.*gen(:,3);
gen(:,9) = rate.*gen(:,9);
gen(:,4) = rate.*gen(:,4);
gen(:,5) = rate.*gen(:,5);
gen(:,10) = rate.*gen(:,10);


bus(:,13:32) = 0; 
busPmax = zeros(size(bus,1),1);
busPmin = zeros(size(bus,1),1);
busPG = zeros(size(bus,1),1);
busQmax = zeros(size(bus,1),1);
busQmin = zeros(size(bus,1),1);
busQG = zeros(size(bus,1),1);
ref = find(bus(:,2) == 3);
pv = find(bus(:,2) == 2);
pq = find(bus(:,2) == 1);


gen(:,11) = 1-8760./(gen(:,7).*gen(:,8)+8760);

for i=1:size(bus,1)
    genindex = find(gen(:,1) == i);
    if(isempty(genindex) ~= 1)
        busPmax(i) = sum(gen(genindex,2));
        busPmin(i) = sum(gen(genindex,3));
        busPG(i)   = sum(gen(genindex,9));
        busQmax(i) = sum(gen(genindex,4));
        busQmin(i) = sum(gen(genindex,5));%%because the Qmin of the generator can be negative
        busQG(i)   = sum(gen(genindex,10));
    else
        busPmax(i) = 0;
        busPmin(i) = 0;
        busQmax(i) = 0;
        busQmin(i) = 0;
        busPG(i) = 0;
        busQG(i) = 0;
    end       
end   

bus(:,13) = busPmax;
bus(:,14) = busPmin;
bus(:,15) = busQmax;
bus(:,16) = busQmin;
bus(:,17) = busPG;
bus(:,18) = busQG;


branch(:,13) = 1-8760./(branch(:,10).*branch(:,11)+8760);
branch(:,14:23) = 0.0;
PBase = prod(1-gen(:,11));
PBase = PBase * prod(1-branch(:,13));
PFBase = sum(gen(:,7));
PFBase = PFBase + sum(branch(:,10));
bus(:,3)=bus(:,3)*0.9;
iw=[1,6];
gen(iw(1),2)=gen(iw(1),2)*0.7;  
gen(iw(2),2)=gen(iw(2),2)*0.7;
end
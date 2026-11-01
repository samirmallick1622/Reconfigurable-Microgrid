% microgrid_params.m
% Parameters for the 12V solar microgrid model.
% This script is run automatically when the model is opened / simulated.

clear P

% simulation
P.Ts = 1;              % step size (s)
P.T_stop = 24*3600;    % simulate one day (s)

% DC bus and loads
P.V_bus = 12;          % bus voltage (V)
P.P_crit = 40;         % critical load (W)
P.P_nc = 40;           % non critical load (W)

% solar panel (36 cell module, approx 160 W)
P.Isc = 8.9;           % short circuit current (A)
P.Voc = 22.5;          % open circuit voltage (V)
P.Ns = 36;             % number of cells
P.n = 1.3;             % diode ideality factor
P.Vt = 0.0257;         % thermal voltage at 25 C (V)
P.a = P.n*P.Ns*P.Vt;
P.I0 = P.Isc/(exp(P.Voc/P.a) - 1);   % diode saturation current
P.P_rated = 150;       % max power the panel gives to the bus at 1000 W/m2 (W)

% buck converter + MPPT
P.eff = 0.95;          % converter efficiency
P.D_min = 0.4;
P.D_max = 0.96;
P.D0 = 0.67;           % starting duty cycle (Vpv = 18V)
P.dD = 0.004;          % P&O step size

% battery 12V 20Ah
P.Ah = 20;
P.SOC0 = 0.3;          % initial SOC
P.Vb_min = 11.6;       % voltage at 0% SOC
P.Vb_max = 13.2;       % voltage at 100% SOC
P.R_bat = 0.05;        % internal resistance (ohm)
P.eff_bat = 0.95;      % charge/discharge efficiency
P.P_chg_max = 100;     % max charging power (W)
P.P_trickle = 10;      % trickle charge from grid (W)
P.SOC_max = 0.95;      % stop charging above this
P.SOC_min = 0.20;      % stop discharging below this

% utility grid
P.V_grid = 230;        % grid voltage (V)
P.V_trip = 184;        % below this the EMS says blackout (0.8 pu)
P.alpha = 0.5;         % filter constant for grid voltage
P.P_grid_max = 200;    % rectifier rating (W)
P.dip = 80;            % voltage dip when a big appliance starts (V)

% noise / filter for scopes
P.noise = 0.25;        % ripple on bus voltage (V)
P.lpf = 0.1;           % low pass filter constant

% ---------------- test scenario for one day ----------------
t = (0:P.Ts:P.T_stop)';
hr = t/3600;

% sunlight: sunrise 6am, sunset 6pm, cloud from 1pm to 2:30pm
G = 1000*max(0, sin(pi*(hr-6)/12));
G(hr >= 13 & hr < 14.5) = 0.25*G(hr >= 13 & hr < 14.5);
irr_ts = timeseries(G, t);

% grid status: 1 = ok, 0 = blackout
grid_status = ones(size(t));
grid_status(hr >= 10.5 & hr < 12) = 0;     % blackout during the day
grid_status(hr >= 18.5 & hr < 23.5) = 0;   % blackout at night
grid_ts = timeseries(grid_status, t);

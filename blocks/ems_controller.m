function [brk_grid, brk_nc, brk_crit, P_bat_ref, P_limit, mode] = ems_controller(P_solar, V_grid, SOC, P)
% Energy Management System
% inputs : P_solar = solar power available (W), V_grid = grid voltage (V), SOC
% outputs: breaker signals (1 = closed), battery power reference
%          (+ve charge, -ve discharge), PV power limit for MPPT, mode
%
% mode 1 : grid ok, solar > load  -> solar feeds load, extra charges battery
% mode 2 : grid ok, solar < load  -> grid gives the rest + trickle charge
% mode 3 : blackout, solar > load -> solar feeds load, extra charges battery
% mode 4 : blackout, solar < load -> switch off non critical, battery feeds critical
% mode 5 : blackout, SOC <= 20%   -> battery cut off to protect it

persistent Vf full
if isempty(Vf)
    Vf = P.V_grid;
    full = 0;
end

% filter the grid voltage so noise does not cause false trips
Vf = Vf + P.alpha*(V_grid - Vf);
grid_ok = Vf > P.V_trip;

P_load = P.P_crit + P.P_nc;

% battery full flag (with hysteresis so it does not keep switching at 95%)
if SOC >= P.SOC_max
    full = 1;
elseif SOC < P.SOC_max - 0.05
    full = 0;
end

if full == 1
    P_chg = 0;
else
    P_chg = P.P_chg_max;
end

brk_grid = 1;
brk_nc = 1;
brk_crit = 1;

if grid_ok
    if P_solar >= P_load
        mode = 1;
        P_bat_ref = min(P_solar - P_load, P_chg);
    else
        mode = 2;
        P_bat_ref = min(P.P_trickle, P_chg);
    end
    P_limit = P_load + P_bat_ref;

else
    brk_grid = 0;   % open main breaker (islanded)

    if P_solar >= P_load
        mode = 3;
        P_bat_ref = min(P_solar - P_load, P_chg);
        P_limit = P_load + P_bat_ref;

    elseif SOC > P.SOC_min
        mode = 4;
        brk_nc = 0;     % load shedding
        P_bat_ref = min(P_solar - P.P_crit, P_chg);   % negative = discharge
        P_limit = P.P_crit + max(P_bat_ref, 0);

    else
        mode = 5;
        brk_nc = 0;
        if P_solar < P.P_crit
            brk_crit = 0;   % not enough power even for critical load
        end
        P_bat_ref = 0;
        P_limit = brk_crit*P.P_crit;
    end
end
end

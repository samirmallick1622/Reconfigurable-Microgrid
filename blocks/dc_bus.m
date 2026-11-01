function [P_grid, P_bat, P_crit, P_nc, V_bus] = dc_bus(P_pv, P_bat_ref, brk_grid, brk_nc, brk_crit, V_post, ripple, P)
% power balance at the 12V DC bus
% grid connected -> grid supplies whatever is missing
% islanded       -> battery supplies whatever is missing

P_crit = brk_crit*P.P_crit;
P_nc = brk_nc*P.P_nc;
P_load = P_crit + P_nc;

if brk_grid == 1 && V_post > 100
    P_grid = P_load + P_bat_ref - P_pv;
    P_grid = min(max(P_grid, 0), P.P_grid_max);
    P_bat = P_pv + P_grid - P_load;
else
    P_grid = 0;
    P_bat = P_pv - P_load;
end

% bus voltage with some converter ripple (0 if all loads are off)
if P_load > 0
    V_bus = P.V_bus + ripple;
else
    V_bus = 0;
end
end

% run_microgrid.m
% Runs the microgrid model for one day and plots the results.

clear; clc; close all;
folder = fileparts(mfilename('fullpath'));
cd(folder);

% fix for "path exceeds 260 characters" error on windows
cache = fullfile(tempdir, 'microgrid_cache');
if ~exist(cache, 'dir')
    mkdir(cache);
end
Simulink.fileGenControl('set', 'CacheFolder', cache, 'CodeGenFolder', cache);

if ~exist('SolarMicrogrid.slx', 'file')
    build_microgrid_model;
end

microgrid_params;
out = sim('SolarMicrogrid');

% get the logged signals
logs = out.logsout;
t = logs.getElement('SOC').Values.Time/3600;     % time in hours
G = logs.getElement('G').Values.Data;
P_pv = logs.getElement('P_pv').Values.Data;
P_solar = logs.getElement('P_solar').Values.Data;
P_grid = logs.getElement('P_grid').Values.Data;
P_bat = logs.getElement('P_bat').Values.Data;
P_load = logs.getElement('P_crit').Values.Data + logs.getElement('P_nc').Values.Data;
SOC = logs.getElement('SOC').Values.Data;
brk_grid = logs.getElement('brk_grid').Values.Data;
brk_nc = logs.getElement('brk_nc').Values.Data;
brk_crit = logs.getElement('brk_crit').Values.Data;
mode = logs.getElement('mode').Values.Data;
V_line = logs.getElement('V_line').Values.Data;
V_post = logs.getElement('V_post').Values.Data;
V_bus = logs.getElement('V_bus').Values.Data;
V_bus_f = logs.getElement('V_bus_filtered').Values.Data;

%% plots
figure('Name', 'Solar Microgrid Results', 'Position', [100 50 1000 900]);

subplot(5,1,1)
plot(t, P_solar, t, P_pv, 'LineWidth', 1.2)
yline(80, '--k', 'Load = 80 W');
ylabel('Power (W)'); title('Solar PV power');
legend('Available', 'Delivered by MPPT'); grid on; xlim([0 24]);

subplot(5,1,2)
plot(t, P_pv, t, P_grid, t, P_bat, t, P_load, 'LineWidth', 1.2)
ylabel('Power (W)'); title('Power flow (battery +ve = charging)');
legend('Solar', 'Grid', 'Battery', 'Load'); grid on; xlim([0 24]);

subplot(5,1,3)
plot(t, SOC*100, 'LineWidth', 1.5)
yline(20, '--r', '20% cut-off');
ylabel('SOC (%)'); title('Battery state of charge'); grid on; xlim([0 24]); ylim([0 100]);

subplot(5,1,4)
plot(t, brk_grid + 4, t, brk_nc + 2, t, brk_crit, t, mode, 'k:', 'LineWidth', 1.2)
title('Breakers (1 = closed) and EMS mode');
legend('Grid breaker (+4)', 'Non-critical (+2)', 'Critical', 'Mode'); grid on; xlim([0 24]);

subplot(5,1,5)
plot(t, V_bus, 'Color', [0.7 0.7 0.7]); hold on
plot(t, V_bus_f, 'b', 'LineWidth', 1.2)
ylabel('Voltage (V)'); xlabel('Time (hours)'); title('12V bus voltage');
legend('Raw', 'Filtered'); grid on; xlim([0 24]); ylim([0 14]);

figure('Name', 'Grid Voltage');
plot(t, V_post, t, V_line, 'LineWidth', 1)
yline(184, '--r', 'Trip level');
xlabel('Time (hours)'); ylabel('Voltage (V)');
title('Grid voltage before and after the main breaker');
legend('After breaker (dips when appliances start)', 'Before breaker (sensor)');
grid on; xlim([0 24]);

%% some results
fprintf('Minimum SOC = %.1f %%\n', min(SOC)*100);
fprintf('Final SOC = %.1f %%\n', SOC(end)*100);
fprintf('Energy from solar = %.0f Wh\n', sum(P_pv)/3600);
fprintf('Energy from grid = %.0f Wh\n', sum(P_grid)/3600);
fprintf('Number of grid breaker operations = %d\n', sum(abs(diff(brk_grid))));
fprintf('Time in each mode (hours):\n');
for m = 1:5
    fprintf('  mode %d : %.2f\n', m, sum(mode == m)/3600);
end

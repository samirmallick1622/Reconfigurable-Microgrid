% build_microgrid_model.m
% Makes the Simulink model SolarMicrogrid.slx
% The code for the MATLAB Function blocks is in the "blocks" folder.
% If you change any of those files run this script again.

clear; clc;
mdl = 'SolarMicrogrid';
folder = fileparts(mfilename('fullpath'));
cd(folder);
microgrid_params;

if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
if exist([mdl '.slx'], 'file')
    delete([mdl '.slx']);
end
new_system(mdl);

% solver settings
set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', ...
    'FixedStep', '1', 'StopTime', num2str(P.T_stop));
set_param(mdl, 'SignalLogging', 'on', 'SignalLoggingName', 'logsout', ...
    'ReturnWorkspaceOutputs', 'on');
% load the parameters every time the model is opened or run
cb = 'run(fullfile(fileparts(get_param(''SolarMicrogrid'',''FileName'')),''microgrid_params.m''));';
set_param(mdl, 'PostLoadFcn', cb, 'InitFcn', cb);

%% inputs
add_block('simulink/Sources/From Workspace', [mdl '/Irradiance'], 'VariableName', 'irr_ts');
add_block('simulink/Sources/From Workspace', [mdl '/Grid_Status'], 'VariableName', 'grid_ts', ...
    'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');

%% solar panel + MPPT
s = [mdl '/Solar_PV_MPPT'];
make_subsystem(s, {'G', 'P_limit'}, {'P_pv', 'P_solar'});
add_fcn_block([s '/PV_Buck_Converter'], 'blocks/pv_buck.m');
add_fcn_block([s '/MPPT'], 'blocks/mppt_po.m');
add_block('simulink/Discrete/Unit Delay', [s '/Delay'], 'InitialCondition', 'P.D0');
add_line(s, 'G/1', 'PV_Buck_Converter/1');
add_line(s, 'Delay/1', 'PV_Buck_Converter/2');
add_line(s, 'PV_Buck_Converter/2', 'MPPT/1');
add_line(s, 'PV_Buck_Converter/3', 'MPPT/2');
add_line(s, 'P_limit/1', 'MPPT/3');
add_line(s, 'MPPT/1', 'Delay/1');
add_line(s, 'PV_Buck_Converter/1', 'P_pv/1');
add_line(s, 'PV_Buck_Converter/4', 'P_solar/1');
Simulink.BlockDiagram.arrangeSystem(s);

%% utility grid (sensor is on the incoming line, before the breaker)
s = [mdl '/Utility_Grid'];
make_subsystem(s, {'status', 'brk_grid'}, {'V_line', 'V_post'});
add_block('simulink/Math Operations/Gain', [s '/230V'], 'Gain', 'P.V_grid');
add_block('simulink/Sources/Random Number', [s '/Noise'], 'Variance', '4', 'SampleTime', '1');
add_block('simulink/Math Operations/Sum', [s '/Add_Noise'], 'Inputs', '++');
add_block('simulink/Sources/Pulse Generator', [s '/Appliance_Dips'], 'PulseType', 'Sample based', ...
    'Amplitude', 'P.dip', 'Period', '7200', 'PulseWidth', '4', 'PhaseDelay', '1800', 'SampleTime', '1');
add_block('simulink/Math Operations/Sum', [s '/Sub_Dip'], 'Inputs', '+-');
add_block('simulink/Math Operations/Product', [s '/Main_Breaker']);
add_line(s, 'status/1', '230V/1');
add_line(s, '230V/1', 'Add_Noise/1');
add_line(s, 'Noise/1', 'Add_Noise/2');
add_line(s, 'Add_Noise/1', 'V_line/1');
add_line(s, 'Add_Noise/1', 'Sub_Dip/1');
add_line(s, 'Appliance_Dips/1', 'Sub_Dip/2');
add_line(s, 'Sub_Dip/1', 'Main_Breaker/1');
add_line(s, 'brk_grid/1', 'Main_Breaker/2');
add_line(s, 'Main_Breaker/1', 'V_post/1');
Simulink.BlockDiagram.arrangeSystem(s);

%% battery
s = [mdl '/Battery'];
make_subsystem(s, {'P_bat'}, {'SOC', 'V_bat'});
add_fcn_block([s '/Battery_Model'], 'blocks/battery_model.m');
add_block('simulink/Discrete/Discrete-Time Integrator', [s '/SOC_Integrator'], ...
    'InitialCondition', 'P.SOC0', 'LimitOutput', 'on', ...
    'UpperSaturationLimit', '1', 'LowerSaturationLimit', '0');
add_line(s, 'P_bat/1', 'Battery_Model/1');
add_line(s, 'SOC_Integrator/1', 'Battery_Model/2');
add_line(s, 'Battery_Model/1', 'SOC_Integrator/1');
add_line(s, 'SOC_Integrator/1', 'SOC/1');
add_line(s, 'Battery_Model/2', 'V_bat/1');
Simulink.BlockDiagram.arrangeSystem(s);

%% EMS controller
add_fcn_block([mdl '/EMS_Controller'], 'blocks/ems_controller.m');
set_param([mdl '/EMS_Controller'], 'Position', [0 0 180 240]);   % bigger so port names fit

%% DC bus + loads
s = [mdl '/DC_Bus'];
make_subsystem(s, {'P_pv', 'P_bat_ref', 'brk_grid', 'brk_nc', 'brk_crit', 'V_post'}, ...
    {'P_grid', 'P_bat', 'P_crit', 'P_nc', 'V_bus', 'V_bus_filtered'});
add_fcn_block([s '/Power_Balance'], 'blocks/dc_bus.m');
add_block('simulink/Sources/Random Number', [s '/Ripple'], 'Variance', 'P.noise^2', 'SampleTime', '1');
add_block('simulink/Discrete/Discrete Transfer Fcn', [s '/Low_Pass_Filter'], ...
    'Numerator', '[P.lpf 0]', 'Denominator', '[1 P.lpf-1]', 'InitialStates', '12/P.lpf');
add_line(s, 'P_pv/1', 'Power_Balance/1');
add_line(s, 'P_bat_ref/1', 'Power_Balance/2');
add_line(s, 'brk_grid/1', 'Power_Balance/3');
add_line(s, 'brk_nc/1', 'Power_Balance/4');
add_line(s, 'brk_crit/1', 'Power_Balance/5');
add_line(s, 'V_post/1', 'Power_Balance/6');
add_line(s, 'Ripple/1', 'Power_Balance/7');
add_line(s, 'Power_Balance/1', 'P_grid/1');
add_line(s, 'Power_Balance/2', 'P_bat/1');
add_line(s, 'Power_Balance/3', 'P_crit/1');
add_line(s, 'Power_Balance/4', 'P_nc/1');
add_line(s, 'Power_Balance/5', 'V_bus/1');
add_line(s, 'Power_Balance/5', 'Low_Pass_Filter/1');
add_line(s, 'Low_Pass_Filter/1', 'V_bus_filtered/1');
Simulink.BlockDiagram.arrangeSystem(s);

%% connect everything at the top level
add_line(mdl, 'Irradiance/1', 'Solar_PV_MPPT/1');
add_line(mdl, 'EMS_Controller/5', 'Solar_PV_MPPT/2');
add_line(mdl, 'Grid_Status/1', 'Utility_Grid/1');
add_line(mdl, 'EMS_Controller/1', 'Utility_Grid/2');
add_line(mdl, 'Solar_PV_MPPT/2', 'EMS_Controller/1');
add_line(mdl, 'Utility_Grid/1', 'EMS_Controller/2');
add_line(mdl, 'Battery/1', 'EMS_Controller/3');
add_line(mdl, 'Solar_PV_MPPT/1', 'DC_Bus/1');
add_line(mdl, 'EMS_Controller/4', 'DC_Bus/2');
add_line(mdl, 'EMS_Controller/1', 'DC_Bus/3');
add_line(mdl, 'EMS_Controller/2', 'DC_Bus/4');
add_line(mdl, 'EMS_Controller/3', 'DC_Bus/5');
add_line(mdl, 'Utility_Grid/2', 'DC_Bus/6');
add_line(mdl, 'DC_Bus/2', 'Battery/1');

%% scopes
add_block('simulink/Sinks/Scope', [mdl '/Power_Scope'], 'NumInputPorts', '3');
add_line(mdl, 'Solar_PV_MPPT/1', 'Power_Scope/1');
add_line(mdl, 'DC_Bus/1', 'Power_Scope/2');
add_line(mdl, 'DC_Bus/2', 'Power_Scope/3');
add_block('simulink/Sinks/Scope', [mdl '/SOC_Scope']);
add_line(mdl, 'Battery/1', 'SOC_Scope/1');
add_block('simulink/Sinks/Scope', [mdl '/Breaker_Scope'], 'NumInputPorts', '4');
add_line(mdl, 'EMS_Controller/1', 'Breaker_Scope/1');
add_line(mdl, 'EMS_Controller/2', 'Breaker_Scope/2');
add_line(mdl, 'EMS_Controller/3', 'Breaker_Scope/3');
add_line(mdl, 'EMS_Controller/6', 'Breaker_Scope/4');
add_block('simulink/Sinks/Scope', [mdl '/Voltage_Scope'], 'NumInputPorts', '2');
add_line(mdl, 'DC_Bus/5', 'Voltage_Scope/1');
add_line(mdl, 'DC_Bus/6', 'Voltage_Scope/2');

%% log signals so they can be plotted later
log_signal(mdl, 'Irradiance', 1, 'G');
log_signal(mdl, 'Grid_Status', 1, 'grid_status');
log_signal(mdl, 'Solar_PV_MPPT', 1, 'P_pv');
log_signal(mdl, 'Solar_PV_MPPT', 2, 'P_solar');
log_signal(mdl, 'Utility_Grid', 1, 'V_line');
log_signal(mdl, 'Utility_Grid', 2, 'V_post');
log_signal(mdl, 'EMS_Controller', 1, 'brk_grid');
log_signal(mdl, 'EMS_Controller', 2, 'brk_nc');
log_signal(mdl, 'EMS_Controller', 3, 'brk_crit');
log_signal(mdl, 'EMS_Controller', 6, 'mode');
log_signal(mdl, 'DC_Bus', 1, 'P_grid');
log_signal(mdl, 'DC_Bus', 2, 'P_bat');
log_signal(mdl, 'DC_Bus', 3, 'P_crit');
log_signal(mdl, 'DC_Bus', 4, 'P_nc');
log_signal(mdl, 'DC_Bus', 5, 'V_bus');
log_signal(mdl, 'DC_Bus', 6, 'V_bus_filtered');
log_signal(mdl, 'Battery', 1, 'SOC');

Simulink.BlockDiagram.arrangeSystem(mdl);
save_system(mdl);
disp('Model created: SolarMicrogrid.slx');


%% ---------- functions used above ----------
function make_subsystem(s, inputs, outputs)
% empty subsystem with named in/out ports
add_block('simulink/Ports & Subsystems/Subsystem', s);
delete_line(s, 'In1/1', 'Out1/1');
delete_block([s '/In1']);
delete_block([s '/Out1']);
for k = 1:length(inputs)
    add_block('simulink/Ports & Subsystems/In1', [s '/' inputs{k}]);
end
for k = 1:length(outputs)
    add_block('simulink/Ports & Subsystems/Out1', [s '/' outputs{k}]);
end
end

function add_fcn_block(path, file)
% MATLAB Function block with code from a .m file, P is a parameter
add_block('simulink/User-Defined Functions/MATLAB Function', path);
chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', path);
chart.Script = fileread(file);
p = find(chart, '-isa', 'Stateflow.Data', 'Name', 'P');
p.Scope = 'Parameter';
end

function log_signal(mdl, block, port, name)
ph = get_param([mdl '/' block], 'PortHandles');
set_param(ph.Outport(port), 'DataLogging', 'on', ...
    'DataLoggingNameMode', 'Custom', 'DataLoggingName', name);
end

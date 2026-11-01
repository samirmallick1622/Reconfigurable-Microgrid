function [dSOC, V_bat, I_bat] = battery_model(P_bat, SOC, P)
% simple battery model
% P_bat +ve = charging, -ve = discharging

Voc = P.Vb_min + (P.Vb_max - P.Vb_min)*SOC;   % open circuit voltage
I_bat = P_bat/Voc;
V_bat = Voc + I_bat*P.R_bat;

% coulomb counting
if I_bat > 0
    dSOC = P.eff_bat*I_bat/(3600*P.Ah);
else
    dSOC = I_bat/(P.eff_bat*3600*P.Ah);
end
end

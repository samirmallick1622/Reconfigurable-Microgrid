function [P_pv, V_pv, I_pv, P_solar] = pv_buck(G, D, P)
% Solar panel (single diode model) + buck converter
% for a buck converter Vout = D*Vin, so the panel voltage is Vpv = Vbus/D

G = max(G, 0);
Iph = P.Isc*G/1000;            % light generated current

D = min(max(D, P.D_min), P.D_max);
V_pv = P.V_bus/D;
I_pv = Iph - P.I0*(exp(V_pv/P.a) - 1);
if I_pv < 0
    I_pv = 0;                  % blocking diode
end

P_pv = P.eff*V_pv*I_pv;        % power going into the 12V bus

% available solar power estimated from irradiance (used by the EMS)
P_solar = P.P_rated*G/1000;
end

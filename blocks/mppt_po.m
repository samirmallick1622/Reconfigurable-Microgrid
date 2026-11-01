function D = mppt_po(V_pv, I_pv, P_limit, P)
% Perturb and Observe MPPT
% if the EMS gives a power limit (battery full) the duty is reduced so the
% panel gives less power

persistent D_old P_old step
if isempty(D_old)
    D_old = P.D0;
    P_old = 0;
    step = -P.dD;
end

P_now = P.eff*V_pv*I_pv;

if P_now < 1
    D = P.D0;                  % night time
elseif P_now > P_limit
    D = D_old - P.dD;          % too much power, move away from MPP
    step = P.dD;
elseif P_now > P_limit - 5
    D = D_old;                 % close enough to the limit, keep D
else
    if P_now < P_old
        step = -step;          % power went down so change direction
    end
    D = D_old + step;
end

D = min(max(D, P.D_min), P.D_max);

D_old = D;
P_old = P_now;
end

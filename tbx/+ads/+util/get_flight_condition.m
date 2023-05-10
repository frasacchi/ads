function [TAS,CAS,rho,a,h] = get_flight_condition(M,opts)
arguments
    M % Mach number
    opts.CAS = []; % calibrated airspeed in m/s
    opts.alt = []; % altitude in ft
    opts.h = []; % altitude in m
end
if isempty(opts.alt) && isempty(opts.CAS) && isempty(opts.h)
    error('Either CAS, alt or h must be supplied')
end
if ~isempty(opts.alt)
    opts.h = 0.3048*opts.alt;
end
if ~isempty(opts.CAS)
    %% create reference data
    x=-1000:100:100000;
    [rho_ref,a_ref,T_ref,P,~,~,~] = ads.util.atmos(x);
    [~,a_s,T_s,P_s,~,~,~] = ads.util.atmos(0);
    CAS_ref = ads.util.calibrated_airspeed(M,P,P_s,a_s,1.4);
    CAS = opts.CAS;
    %% interpolate data to requested flight conditions
    rho = interp1(CAS_ref,rho_ref,CAS);
    a = interp1(CAS_ref,a_ref,CAS);
    h = interp1(CAS_ref,x,CAS);
    T = interp1(CAS_ref,T_ref,CAS);
    TAS = ads.util.true_airspeed(M,a,T,T_s);
else
    [rho,a,T,P,~,~,~] = ads.util.atmos(opts.h);
    [~,a_s,T_s,P_s,~,~,~] = ads.util.atmos(0);
    CAS = ads.util.calibrated_airspeed(M,P,P_s,a_s,1.4);
    TAS = ads.util.true_airspeed(M,a,T,T_s);
    h = opts.h;
end


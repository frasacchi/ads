function [TAS,CAS,rho,a,h] = get_flight_condition(M,opts)
arguments
    M % Mach number
    opts.CAS = nan; % calibrated airspeed in m/s
    opts.alt = nan; % altitude in ft
    opts.h = nan; % altitude in m
end
if isnan(opts.alt) && isnan(opts.CAS) && isnan(opts.h)
    error('Either CAS, alt or h must be supplied')
end
if ~isnan(opts.alt)
    opts.h = 0.3048*opts.alt;
end
if ~isnan(opts.CAS)
    %% create reference data
    x=-1000:100:100000;
    [rho_ref,a_ref,~,P,~,~,~] = atmos(x);
    [~,a_s,T_s,P_s,~,~,~] = atmos(0);
    CAS = ads.util.calibrated_airspeed(M,P,P_s,a_s,1.4);
    
    %% interpolate data to requested flight conditions
    rho = interp1(v_cal_ref,rho_ref,v_cal);
    a = interp1(v_cal_ref,a_ref,v_cal);
    h = interp1(v_cal_ref,x,v_cal);
    TAS = ads.util.true_airspeed(M,a,T,T_s);
else
    [rho,a,T,P,~,~,~] = ads.util.atmos(opts.h);
    [~,a_s,T_s,P_s,~,~,~] = ads.util.atmos(0);
    CAS = ads.util.calibrated_airspeed(M,P,P_s,a_s,1.4);
    TAS = ads.util.true_airspeed(M,a,T,T_s);
    h = opts.h;
end


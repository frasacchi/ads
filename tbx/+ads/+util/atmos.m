function [rho,a,T,P,nu,z,sigma] = atmos(h,tOffset)
%  ATMOS  Find gas properties in the 1976 Standard Atmosphere.
%   [rho,a,T,P,nu,z,sigma] = ATMOS(h,opts)
%
%   ATMOS by itself gives atmospheric properties at sea level on a standard day.
%
%   ATMOS(h) returns the properties of the 1976 Standard Atmosphere at
%   geopotential altitude h, where h is a scalar, vector, matrix, or ND array.
% 
%   The input h can be followed by parameter/value pairs for further control of
%   ATMOS. Possible parameters are:
%     tOffset      - Returns properties when the temperature is tOffset degrees 
%                    above or below standand conditions. h and tOffset must be
%                    the same size or else one must be a scalar. Default is no
%                    offset. Note that this is an offset, so when converting
%                    between Celsius and Fahrenheit, use only the scaling factor
%                    (dC/dF = dK/dR = 5/9).
%
%                                 Description:         SI:
%                     Input:      --------------       -----
%                       h | z     Altitude or height   m
%                       tOffset   Temp. offset         °C/°K
%                     Output:     --------------       -----
%                       rho       Density              kg/m^3
%                       a         Speed of sound       m/s
%                       T         Temperature          °K
%                       P         Pressure             Pa
%                       nu        Kinem. viscosity     m^2/s
%                       z | h     Height or altitude   m
%                       sigma     Density ratio        -
%
%   ATMOS returns properties the same size as h and/or tOffset (P does not vary
%   with temperature offset and is always the size of h).
%
%   Example 1: Find atmospheric properties at every 100 m of geometric height
%   for an off-standard atmosphere with temperature offset varying +/- 25°C
%   sinusoidally with a period of 4 km.
%       z = 0:100:86000;
%       [rho,a,T,P,nu,h,sigma] = atmos(z,'tOffset',25*sin(pi*z/2000),...
%                                        'altType','geometric');
%       semilogx(sigma,h/1000)
%       title('Density variation with sinusoidal off-standard atmosphere')
%       xlabel('Density ratio, \sigma'); ylabel('Geopotential altitude (km)')
%
%   Example 2: Create tables of atmospheric properties up to 30,000 ft for a
%   cold (-20°C), standard, and hot (+20°C) day with columns
%   [h(ft) z(ft) rho(slug/ft³) sigma a(ft/s) T(R) P(psf) µ(slug/ft-s) nu(ft²/s)]
%   leveraging n-dimensional array capability.
%       [~,h,dT] = meshgrid(0,-5000:1000:30000,[-20 0 20]);
%       [rho,a,T,P,nu,z,sigma] = atmos(h,'tOffset',dT*9/5,'units','US');
%       t = [h z rho sigma a T P nu.*rho nu];
%       format short e
%       varNames = {'h' 'z' 'rho' 'sigma' 'a' 'T' 'P' 'mu' 'nu'};
%       ColdTable       = array2table(t(:,:,1),'VariableNames',varNames)
%       StandardTable   = array2table(t(:,:,2),'VariableNames',varNames)
%       HotTable        = array2table(t(:,:,3),'VariableNames',varNames)
%
%   Example 3: Use the unit consistency enforced by the DimVar class to find the
%   SI dynamic pressure, Mach number, Reynolds number, and stagnation
%   temperature of an aircraft flying at flight level FL500 (50000 ft) with
%   speed 500 knots and characteristic length of 80 inches.
%       V = 500*u.kts; c = 80*u.in;
%       o = atmos(50*u.kft,'structOutput',true);
%       Dyn_Press = 1/2*o.rho*V^2;
%       M = V/o.a;
%       Re = V*c/o.nu;
%       T0 = o.T*(1+(1.4-1)/2*M^2);
%
%   This model is not recommended for use at altitudes above 86 km geometric
%   height (84852 m / 278386 ft geopotential) but will attempt to extrapolate
%   above 86 km (with a lapse rate of 0°/km) and below 0.
%
%   See also ATMOSISA, ATMOSNONSTD, TROPOS, DENSITYALT ,
%     U - http://www.mathworks.com/matlabcentral/fileexchange/38977.
%
%   [rho,a,T,P,nu,z,sigma] = ATMOS(h,varargin)
%   Copyright 2015 Sky Sartorius
%   www.mathworks.com/matlabcentral/fileexchange/authors/101715
% 
%   References: ESDU 77022; www.pdas.com/atmos.html
arguments
    h = 0;
    tOffset = 0;
end

%% Parse inputs:
if length(h)==1 && h==0 && tOffset==0
    % Quick return of sea level conditions.
    rho = 1.225;
    a = sqrt(115800);
    T = 288.15;
    P = 101325;
    nu = (1.458e-6 * T.^1.5 ./ 398.55) ./ rho;
    z = 0;
    sigma = 1;
    return
end
%% Constants, etc.:
%  Lapse rate Base Temp       Base Geop. Alt    Base Pressure
%   Ki (°C/m) Ti (°K)         Hi (m)            P (Pa)
D =[-0.0065   288.15          0                 101325            % Troposphere
    0         216.65          11000             22632.04059693474 % Tropopause
    0.001     216.65          20000             5474.877660660026 % Stratosph. 1
    0.0028    228.65          32000             868.0158377493657 % Stratosph. 2
    0         270.65          47000             110.9057845539146 % Stratopause
    -0.0028   270.65          51000             66.938535373039073% Mesosphere 1
    -0.002    214.65          71000             3.956392754582863 % Mesosphere 2
    0         186.94590831019 84852.04584490575 .373377242877530];% Mesopause
% Constants:
rho0 = 1.225;   % Sea level density, kg/m^3
gamma = 1.4;
g0 = 9.80665;   %m/sec^2
RE = 6356766;   %Radius of the Earth, m
Bs = 1.458e-6;  %N-s/m2 K1/2
S = 110.4;      %K
K_D = D(:,1);	%°K/m
T_D = D(:,2);	%°K
H = D(:,3);	%m
P_D = D(:,4);	%Pa
R = P_D(1)/T_D(1)/rho0; %N-m/kg-K
% Ref:
%   287.05287 N-m/kg-K: value from ESDU 77022
%   287.0531 N-m/kg-K:  value used by MATLAB aerospace toolbox ATMOSISA
%% Calculate temperature and pressure:
% Pre-allocate.
[T,P] = deal(zeros(size(h)));
nSpheres = size(D,1);
for i = 1:nSpheres
    % Put inputs into the right altitude bins:
    if i == 1 % Extrapolate below first defined atmosphere.
        n = h <= H(2);
    elseif i == nSpheres % Capture all above top of defined atmosphere.
        n = h > H(nSpheres);
    else 
        n = h <= H(i+1) & h > H(i);
    end
       
    if K_D(i) == 0 % No temperature lapse.
        T(n) = T_D(i);
        P(n) = P_D(i) * exp(-g0*(h(n)-H(i))/(T_D(i)*R));
    else
        TonTi = 1 + K_D(i)*(h(n) - H(i))/T_D(i);
        T(n) = TonTi*T_D(i); 
        P(n) = P_D(i) * TonTi.^(-g0/(K_D(i)*R)); % Undefined for K = 0.
    end
end
%% Switch between using standard temp and provided absolute temp.
T = T + tOffset;
%% Populate the rest of the parameters:
rho = P./T/R;
sigma = rho/rho0;
a = sqrt(gamma * R * T);
nu = (Bs * T.^1.5 ./ (T + S)) ./ rho; %m2/s
z = RE*h./(RE-h);
end

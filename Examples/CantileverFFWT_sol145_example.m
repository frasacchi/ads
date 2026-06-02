%% Example Exicution of a SOL145 solution in MSC NAstran
% model is of a cantilever wing suitable for WT testing and utilises the 
% baff file format to generate a model
% flutter analysis
clear all
%% Create the FeModel

% get baff model from private function
model = CantileverFFWT(0,15);  % parameters are the fold and 'flare' angle of the wingtip
% re-interppolate beam sections to ensure fe model has a certauin number of
% beams
model.Wing(1).Stations = model.Wing(1).Stations.interpolate(linspace(0,1,12));
model.Wing(2).Stations = model.Wing(2).Stations.interpolate(linspace(0,1,4));

%convert to an FE Model
fe = ads.baff.baff2fe(model);
%update aero panels to 4 panels along the chord and an aspect ratio as
%close to 1 as possible
fe.AeroSurfaces.SetPanelNumbers(4,1,"Span");

% plot the model
f = figure(1);
clf;
hold on
fe.draw();
ax = gca;
ax.Clipping = false;
ax.ZAxis.Direction = "reverse";
axis equal

%% Setup 145 Analysis with Nastran
Us = 0.25:0.25:40;  % velocity in m/s

%flatten the FE model and update the element ID numbers
fe = fe.Flatten;
IDs = fe.UpdateIDs();

% Add Aero Settings
% as model was defined with LE at a postive x postion the aero coordinate
% sytem has to point in the opposite direction (wind moves in positive x direction in aero coord system)
fe.CoordSys(end+1) = ads.fe.CoordSys(Origin=[0;0;0],A=dcrg.rotzd(180));
fe.AeroSettings(1) = ads.fe.AeroSettings(0.12,1,2,2*0.12,ACSID=fe.CoordSys(end),SymXZ=true);
for i = 1:length(fe.AeroSurfaces)
    fe.AeroSurfaces(i).AeroCoordSys = fe.CoordSys(end);
end

IDs = fe.UpdateIDs();


% create the 'sol' object and update the IDs
sol = ads.nast.Sol145();
sol.FreqRange = [0 200];
sol.V = Us;
sol.Mach = zeros(size(Us));
sol.rho = ones(size(Us))*1.225;
sol.FlutterMethod = 'PKNL';
sol.UpdateID(IDs);

% run Nastran
Log.setLevel("Trace");
[sol.Outputs.WriteToF06] = deal(false); % minimise output in F06 file
BinFolder = sol.build(fe,'ex_ffwt_sol145');
sol.run(BinFolder);
res = sol.ExtractResults(BinFolder);

%% plot V-G diagrams
f = figure(2);
clf;
clf;
tiledlayout(2,1);
nexttile(1);
ads.nast.plot.flutter(res,NModes=3,XAxis='V',YAxis='F');
xlabel('Velocity [m/s]')
ylabel('Frequency [deg]')
nexttile(2);
ads.nast.plot.flutter(res,NModes=3,XAxis='V',YAxis='D');
xlabel('Velocity [m/s]')
ylabel('Damping Ratio')



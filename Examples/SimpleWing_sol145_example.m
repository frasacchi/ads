%% Example Exicution of a SOL145 solution in MSC NAstran
% model is of a cantilever wing suitable for WT testing and utilises the 
% baff file format to generate a model
fclose all;
clear all
%% Create the FeModel

% get baff model from private function
model = UniformBaffWing(BarChordwisePos=0.5,IncludeTipMass=true);

%convert to an FE Model
fe = ads.baff.baff2fe(model);

% plot the model
f = figure(1);
clf;
hold on
fe.draw();
ax = gca;
ax.Clipping = false;
ax.ZAxis.Direction = "reverse";
axis equal

%% Setup 103 Analysis with Nastran
Us = 0.2:0.2:100;  % velocity in m/s

%flatten the FE model and update the element ID numbers
fe = fe.Flatten;
IDs = fe.UpdateIDs();

% Add Aero Settings
fe.CoordSys(end+1) = ads.fe.CoordSys(Origin=[0;0;0],A=eye(3));
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
ads.nast.plot.flutter(res,NModes=4,XAxis='V',YAxis='F');
xlabel('Velocity [m/s]')
ylabel('Frequency [deg]')
nexttile(2);
ads.nast.plot.flutter(res,NModes=4,XAxis='V',YAxis='D');
xlabel('Velocity [m/s]')
ylabel('Damping Ratio')
ylim([-1 1])



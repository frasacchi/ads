%% Example Exicution of a SOL144 solution in MSC NAstran
% model is of a cantilever wing suitable for WT testing and utilises the 
% baff file format to generate a model
fclose all;
clear all
%% Create the FeModel

% get baff model from private function
model = UniformBaffWing();

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
U = 18;  % velocity in m/s
aoa = 10; % AoA in degrees

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
sol = ads.nast.Sol144();
sol.set_trim_locked(U,1.225,0); %V, rho, Mach
sol.ANGLEA.Value = -deg2rad(aoa);
sol.Grav_Vector = [0 0 1];
sol.LoadFactor = 0;
sol.UpdateID(IDs);

% run Nastran
BinFolder = 'ex_uw_sol144';
sol.run(fe,Silent=false,NumAttempts=1,BinFolder=BinFolder);

%% load Nastran model and plot deformation
filename = fullfile(BinFolder,'bin','sol144.h5');
resFile = mni.result.hdf5(filename);
res = resFile.read_displacements;

% load Nastran model and plot deformation
f = figure(2);
clf;
nas_model = mni.import_matran(fullfile(char(BinFolder),'Source','sol144.bdf'),'LogFcn',@(a,b,c)fprintf(''));
nas_model.draw(f);
[~,i] = ismember(nas_model.GRID.GID,res.GID);
nas_model.GRID.Deformation = [res.X(i),res.Y(i),res.Z(i)]';
nas_model.update()
ax = gca;
ax.Clipping = false;
ax.ZAxis.Direction = "reverse";
axis equal
% you can click things in the legend to hide them and move around the model
% with the mouse

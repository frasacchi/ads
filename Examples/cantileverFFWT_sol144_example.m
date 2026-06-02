%% Example Exicution of a SOL144 solution in MSC NAstran
% model is of a cantilever wing + FFWT suitable for WT testing and utilises the 
% baff file format to generate a model
% static aeroelastic analysis
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

%% Setup 144 Analysis with Nastran
U = 1;  % velocity in m/s
aoa = 0; % AoA in degrees

%flatten the FE model and update the element ID numbers
fe = fe.Flatten;
IDs = fe.UpdateIDs();

% as model was defined with LE at a postive x postion the aero coordinate
% sytem has to point in the opposite direction (wind moves in positive x direction in aero coord system)
fe.CoordSys(end+1) = ads.fe.CoordSys(Origin=[0;0;0],A=dcrg.rotzd(180));
fe.AeroSettings(1) = ads.fe.AeroSettings(0.12,1,2,2*0.12,ACSID=fe.CoordSys(end),SymXZ=true);
for i = 1:length(fe.AeroSurfaces)
    fe.AeroSurfaces(i).AeroCoordSys = fe.CoordSys(end);
end
IDs = fe.UpdateIDs();


% create the 'sol' object and update the IDs
sol = ads.nast.Sol144();
sol.set_trim_locked(U,1.225,0); %V, rho, Mach
sol.ANGLEA.Value = deg2rad(aoa);
sol.Grav_Vector = [0 0 0];
sol.g = 0;
sol.LoadFactor = 0;
sol.UpdateID(IDs);

% run Nastran
Log.setLevel("Trace");
[sol.Outputs.WriteToF06] = deal(false); % minimise output in F06 file
BinFolder = sol.build(fe,'ex_ffwt_sol144');
sol.run(BinFolder);

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

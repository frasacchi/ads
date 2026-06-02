%% Example Exicution of a SOL101 solution in MSC NAstran
% model is of a cantilever wing suitable for WT testing and utilises the 
% baff file format to generate a model

%% Create the FeModel
fclose all;
clear all
% get baff model from private function
model = UniformBaffWing();

% apply a point force the the wingtip
force = baff.Point(eta=1,Name="TipLoad",Force=[0;0;30]);
model.Wing(1).add(force);
model = model.Rebuild;

%convert to an FE Model
fe = ads.baff.baff2fe(model);
%set aero panel density
% sets 4 panesl on chord and panels will have an aspect ratio of 1
fe.AeroSurfaces.SetPanelNumbers(4,1,'Span') 

% plot the model
f = figure(1);
clf;
hold on
fe.draw();
ax = gca;
ax.Clipping = false;
ax.ZAxis.Direction = "reverse";
axis equal

%% Setup 101 Analysis with Nastran

%flatten the FE model and update the element ID numbers
fe = fe.Flatten;
IDs = fe.UpdateIDs();

% create the 'sol' object and update the IDs
sol = ads.nast.Sol101();
sol.g = 0;                  % disable gravity
sol.UpdateID(IDs);

% run Nastran
BinFolder = 'ex_uw_sol101';
Log.setLevel("Trace") % see all messages
sol.Outputs(end+1) = ads.nast.OutRequest('ACCELERATION');
sol.Outputs(end+1) = ads.nast.OutRequest('GPFORCE');
sol.Outputs(end+1) = ads.nast.OutRequest('FORCE');
[sol.Outputs.WriteToF06] = deal(false); % minimise output in F06 file
BinFolder = sol.build(fe,BinFolder);
sol.run(BinFolder);

% read result
filename = fullfile(BinFolder,'bin','sol101.h5');
resFile = mni.result.hdf5(filename);
res = resFile.read_displacements;

%load Nastran model and plot deformation
f = figure(2);
clf;
nas_model = mni.import_matran(fullfile(char(BinFolder),'Source','sol101.bdf'),'LogFcn',@(a,b,c)fprintf(''));
nas_model.draw(f);
[~,i] = ismember(nas_model.GRID.GID,res.GID);
nas_model.GRID.Deformation = [res.X(i),res.Y(i),res.Z(i)]';
nas_model.update()
ax = gca;
ax.Clipping = false;
% ax.ZAxis.Direction = "reverse";
axis equal
% you can clicl things in the legend to hide them and move around the model
% with the mouse

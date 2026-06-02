%% Example Exicution of a SOL103 solution in MSC NAstran
% model is of a cantilever wing suitable for WT testing and utilises the 
% baff file format to generate a model

%% Create the FeModel
fclose all;
clear all
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

%flatten the FE model and update the element ID numbers
fe = fe.Flatten;
IDs = fe.UpdateIDs();

% create the 'sol' object and update the IDs
sol = ads.nast.Sol103();
sol.FreqRange = [0 100];
sol.g = 0;                  % disable gravity
sol.UpdateID(IDs);

% run Nastran
Log.setLevel("Trace") % see all messages
sol.Outputs(end+1) = ads.nast.OutRequest('GPFORCE');
[sol.Outputs.WriteToF06] = deal(false); % minimise output in F06 file
BinFolder = sol.build(fe,'ex_uw_sol103');
sol.run(BinFolder);

%% load Nastran model and plot deformation for the N'th mode
filename = fullfile(BinFolder,'bin','sol103.h5');
resFile = mni.result.hdf5(filename);
res = resFile.read_modeshapes;
N=1;
f = figure(2);
clf;
nas_model = mni.import_matran(fullfile(char(BinFolder),'Source','sol103.bdf'),'LogFcn',@(a,b,c)fprintf(''));
nas_model.draw(f);
[~,i] = ismember(nas_model.GRID.GID,res(N).IDs);
nas_model.GRID.Deformation = [res(N).EigenVector(i,1:3)]';
nas_model.update()
ax = gca;
ax.Clipping = false;
% ax.ZAxis.Direction = "reverse";
axis equal
% you can clicl things in the legend to hide them and move around the model
% with the mouse

%% animate the Modeshape
%mode number to plot
N = 5;
[~,i] = ismember(nas_model.GRID.GID,res(N).IDs);
nas_model.GRID.Deformation = [res(N).EigenVector(i,1:3)]';

nas_model.animate(Period=2,Cycles=2,Scale=1);
nas_model.update()


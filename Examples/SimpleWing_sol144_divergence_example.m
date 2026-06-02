%% Example Exicution of a SOL144 solution in MSC NAstran
% model is of a cantilever wing suitable for WT testing and utilises the
% baff file format to generate a model
fclose all;
clear all
%% Create the FeModel
Sweeps = unique([-20:5:10,-9:-6]);
Sweeps = 0;
% Sweeps = -8;
Vd = nan(5,length(Sweeps));
for si=1:length(Sweeps)
    % get baff model from private function
    BarChordwisePos = 0.1;
    Sweep = Sweeps(si);
    fprintf('Running Model with nbeam Eta %.2f and sweep %.2f deg\n',BarChordwisePos*100,Sweep)
    model = UniformBaffWing(BarChordwisePos=BarChordwisePos,IncludeTipMass=false,IncludeMasses=true,Sweep = Sweep);

    %convert to an FE Model
    opts = ads.baff.BaffOpts();
    opts.SplitBeamsAtChildren = false;
    fe = ads.baff.baff2fe(model,opts);


    %% Setup Divergence Analysis with Nastran
    Mach = 0;  % velocity in m/s
    aoa = 0; % AoA in degrees

    %flatten the FE model and update the element ID numbers
    fe = fe.Flatten;
    IDs = fe.UpdateIDs();

    % Add Aero Settings
    fe.CoordSys(end+1) = ads.fe.CoordSys(Origin=[0;0;0],A=eye(3));
    fe.AeroSettings(1) = ads.fe.AeroSettings(0.12,1,2,2*0.12,ACSID=fe.CoordSys(end),SymXZ=true);
    for i = 1:length(fe.AeroSurfaces)
        fe.AeroSurfaces(i).AeroCoordSys = fe.CoordSys(end);
        fe.AeroSurfaces(i).SetPanelNumbers(8,1,'Span');
        fe.AeroSurfaces(i).SplineType = 4;
    end
    IDs = fe.UpdateIDs();


    % plot the model
    % f = figure(1);
    % clf;
    % hold on
    % fe.draw();
    % ax = gca;
    % ax.Clipping = false;
    % ax.ZAxis.Direction = "reverse";
    % axis equal


    % create the 'sol' object and update the IDs
    sol = ads.nast.Divergence(Mach,5);
    sol.UpdateID(IDs);

    % run Nastran
    BinFolder = sprintf('ex_sol144_div_b%.0f_sw_%.0f',BarChordwisePos*100,Sweep);
    Log.setLevel("Debug");
    [sol.Outputs.WriteToF06] = deal(false); % minimise output in F06 file
    BinFolder = sol.build(fe,BinFolder);
    sol.run(BinFolder);

    %% load Nastran model and plot deformation
    filename = fullfile(BinFolder,'bin','sol144_div.h5');
    resFile = mni.result.hdf5(filename);
    res = resFile.read_divergence;
    if ~isempty(res)
        for i = 1:length(res)
            Vd(i,si) = sqrt(res(i).Q*2/1.225);
        end
    end
    % Vd
end
f = figure(1);
hold on
% clf;
sw = repmat(Sweeps,5,1);
plot(sw(:),Vd(:),'o')

%% FLUTTER
% Setup 145 Analysis with Nastran
% Us = 0.2:0.2:200;  % velocity in m/s
%
% %flatten the FE model and update the element ID numbers
% fe = fe.Flatten;
%
% % Add Aero Settings
% fe.CoordSys(end+1) = ads.fe.CoordSys(Origin=[0;0;0],A=eye(3));
% fe.AeroSettings(1) = ads.fe.AeroSettings(0.12,1,2,2*0.12,ACSID=fe.CoordSys(end),SymXZ=true);
% for i = 1:length(fe.AeroSurfaces)
%     fe.AeroSurfaces(i).AeroCoordSys = fe.CoordSys(end);
% end
% IDs = fe.UpdateIDs();
%
% % create the 'sol' object and update the IDs
% sol = ads.nast.Sol145();
% sol.FreqRange = [0 200];
% sol.V = Us;
% sol.Mach = zeros(size(Us));
% sol.rho = ones(size(Us))*1.225;
% sol.FlutterMethod = 'PKNL';
% sol.UpdateID(IDs);
%
% % run Nastran
% BinFolder = sprintf('ex_sol145_b%.0f',BarChordwisePos*100);
% res = sol.run(fe,Silent=true,NumAttempts=1,BinFolder=BinFolder);

%% plot V-G diagrams
% f = figure(10);
% clf;
% clf;
% tiledlayout(2,1);
% nexttile(1);
% ads.nast.plot.flutter(res,NModes=3,XAxis='V',YAxis='F');
% xlabel('Velocity [m/s]')
% ylabel('Frequency [deg]')
% grid on
% nexttile(2);
% ads.nast.plot.flutter(res,NModes=3,XAxis='V',YAxis='D');
% xlabel('Velocity [m/s]')
% ylabel('Damping Ratio')
% ylim([-0.5 0.2])
% grid on


%% FLUTTER - diverg vector
% Setup 145 Analysis with Nastran
Us = -20;  % velocity in m/s

%flatten the FE model and update the element ID numbers
% fe = fe.Flatten;
%
% % Add Aero Settings
% fe.CoordSys(end+1) = ads.fe.CoordSys(Origin=[0;0;0],A=eye(3));
% fe.AeroSettings(1) = ads.fe.AeroSettings(0.12,1,2,2*0.12,ACSID=fe.CoordSys(end),SymXZ=true);
% for i = 1:length(fe.AeroSurfaces)
%     fe.AeroSurfaces(i).AeroCoordSys = fe.CoordSys(end);
% end
% IDs = fe.UpdateIDs();
%
% % create the 'sol' object and update the IDs
% sol = ads.nast.Sol145();
% sol.FreqRange = [0 200];
% sol.V = Us;
% sol.Mach = zeros(size(Us));
% sol.rho = ones(size(Us))*1.225;
% sol.FlutterMethod = 'PKNL';
% sol.UpdateID(IDs);
%
% % run Nastran
% BinFolder = sprintf('ex_uw_sol145_b%.0f',BarChordwisePos*100);
% res = sol.run(fe,Silent=true,NumAttempts=1,BinFolder=BinFolder);
%
%
% % model = mni.import_matran(fullfile(BinFolder,'Source','sol145.bdf'));
% % model.draw;
%
%
%
% %% apply deformation result
% % [~,i] = ismember(model.GRID.GID,res(1).IDs);
% % model.GRID.Deformation = res(1).EigenVector(:,[1,2,5]);
% % model.update('Scale',50)
%
%
% f = figure(12);
% % clf;
% hold on
% ys = real(res(1).EigenVector(2:21,5));
% xs = linspace(0,1,length(ys));
% plot(xs,ys,'DisplayName',[sprintf('%.0f',BarChordwisePos*100),'%'])
% ylabel('Twist [deg]')
% xlabel('normailised spanwise position')







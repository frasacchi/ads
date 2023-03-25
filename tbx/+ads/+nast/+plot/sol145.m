close all
model = mni.import_matran('C:\Git\fwtfemlite\sol145.bdf');
model.draw
res_disp = mni.result.f06.read_f06_disp('','sol144');
res_aeroP = mni.result.f06.read_f06_aeroP('','sol144');
res_aeroF = mni.result.f06.read_f06_aeroF('','sol144');

% apply deformation result
[~,i] = ismember(model.GRID.GID,res_disp.GP);
model.GRID.Deformation = [res_disp.dX(:,i);res_disp.dY(:,i);res_disp.dZ(:,i)];

% apply aero result
model.CAERO1.PanelPressure = res_aeroP.Cp;

f = [res_aeroF.aeroFx;res_aeroF.aeroFy;res_aeroF.aeroFz;...
    res_aeroF.aeroMx;res_aeroF.aeroMy;res_aeroF.aeroMz];

model.CAERO1.PanelForce = f';
model.update()

function model = sol145(bin_folder,modeshape_num,varargin)

    p = inputParser();
    p.addParameter('Animate',true,@(x)islogical(x));
    p.parse(varargin{:});
    
    close all
    model = mni.import_matran(fullfile(bin_folder,'Source','sol145.bdf'));
    model.draw;

    % get modal data
    f06 = mni.result.f06(fullfile(bin_folder,'bin','sol103.f06'));
    res_modeshape = f06.read_modeshapes;
    res_freq = f06.read_modes;
    %% apply deformation result
    [~,i] = ismember(model.GRID.GID,res_modeshape.GID(modeshape_num,:));
    model.GRID.Deformation = [res_modeshape.T1(modeshape_num,i);...
        res_modeshape.T2(modeshape_num,i);res_modeshape.T3(modeshape_num,i)];

    model.update()
    if p.Results.Animate
        model.animate('Frequency',2,'Scale',0.2) 
    end
end
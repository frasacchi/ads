function model = sol101(bin_folder)
close all
model = mni.import_matran(fullfile(bin_folder,'Source','sol101.bdf'));
model.draw;
res =  mni.result.f06(fullfile(bin_folder,'bin','sol101.f06'));
res_disp = res.read_disp();

% apply deformation result
[~,i] = ismember(model.GRID.GID,res_disp.GP);
model.GRID.Deformation = [res_disp.dX(:,i);res_disp.dY(:,i);res_disp.dZ(:,i)];
disp(rad2deg(res_disp.thX(res_disp.GP == 209)))
disp(rad2deg(res_disp.thX(res_disp.GP == 208)))

%% apply aero result
% model.CAERO1.PanelPressure = res_aeroP.Cp;

%f = [res_aeroF.aeroFx;res_aeroF.aeroFy;res_aeroF.aeroFz;...
%    res_aeroF.aeroMx;res_aeroF.aeroMy;res_aeroF.aeroMz];

%model.CAERO1.PanelForce = f';
model.update('Scale',1);
end
function model = sol144(bin_folder)
arguments
    bin_folder char
end
    model = mni.import_matran(fullfile(bin_folder,'Source','sol144.bdf'));
    model.draw;
    % hdf = mni.result.hdf5(fullfile(bin_folder,'bin','sol144.h5'));

    f06 =  mni.result.f06(fullfile(bin_folder,'bin','sol144.f06'));
    res_disp =  f06.read_disp;
    res_aeroP = f06.read_aeroP;
    res_aeroF = f06.read_aeroF;

    % apply deformation result
    [~,i] = ismember(model.GRID.GID,res_disp.GP);
    model.GRID.Deformation = [res_disp.dX(:,i);res_disp.dY(:,i);res_disp.dZ(:,i)];

    %% apply aero result
    model.CAERO1.PanelPressure = res_aeroP.Cp;

    f = [res_aeroF.aeroFx;res_aeroF.aeroFy;res_aeroF.aeroFz;...
        res_aeroF.aeroMx;res_aeroF.aeroMy;res_aeroF.aeroMz];

    model.CAERO1.PanelForce = f';
    model.update('Scale',1)
end

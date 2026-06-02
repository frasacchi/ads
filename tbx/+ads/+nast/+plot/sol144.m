function model = sol144(bin_folder,f,plotOpts)
arguments
    bin_folder char
    f = figure()
    plotOpts = mni.bulk.PlotOpts();
end
    model = mni.import_matran(fullfile(bin_folder,'Source','sol144.bdf'),'ExpandInclude',true);
    model.draw;
    % hdf = mni.result.hdf5(fullfile(bin_folder,'bin','sol144.h5'));

    f06 =  mni.result.f06(fullfile(bin_folder,'bin','sol144.f06'));
    res_disp =  f06.read_disp;
    res_aeroP = f06.read_aeroP;
    res_aeroF = f06.read_aeroF;

    % apply deformation result
    [~,i] = ismember(model.GRID.GID,res_disp.GID);
    model.GRID.Deformation = [res_disp.X(i),res_disp.Y(i),res_disp.Z(i)];

    %% apply aero result
    model.CAERO1.PanelPressure = res_aeroP.Cp;
    model.CAERO1.PanelForce = [res_aeroF.F,res_aeroF.M];
    model.update(plotOpts)
end

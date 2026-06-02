function [res_disp,res_aeroP,res_aeroF] = ExtractResults(obj,BinFolder)
arguments
    obj
    BinFolder
end

h5_file = mni.result.hdf5(fullfile(BinFolder,'bin',[char(obj.Name),'.h5']));
switch nargout
    case 1
        res_disp =  h5_file.read_displacements;
    case 2
        res_disp =  h5_file.read_displacements;
        res_aeroP = h5_file.read_aero_pressure;
    case 3
        res_disp =  h5_file.read_displacements;
        res_aeroP = h5_file.read_aero_pressure;
        res_aeroF = h5_file.read_aero_force;
end
end
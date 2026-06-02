function data = ExtractResults(obj,BinFolder,opts)
    arguments
        obj
        BinFolder
        opts.IncludeEigenVec = false;
    end
    h5_file = mni.result.hdf5(fullfile(BinFolder,'bin',[char(obj.Name),'.h5']));
    if opts.IncludeEigenVec
        data = h5_file.read_modeshapes();
    else
        data = h5_file.read_modes();
    end
end
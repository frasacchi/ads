function res = ExtractResults(obj,BinFolder,opts)
    arguments
        obj
        BinFolder
        opts.IncludeEigenVec = false;
        opts.UseHdf5 = true;
    end
    if opts.UseHdf5
        h5_file = mni.result.hdf5(fullfile(BinFolder,'bin',[char(obj.Name),'.h5']));
        res = h5_file.read_flutter_summary();
        if opts.IncludeEigenVec
            res_vec = h5_file.read_flutter_eigenvector();
        end
    else
        f06_file = mni.result.f06(fullfile(BinFolder,'bin',[char(obj.Name),'.f06']));
        res = f06_file.read_flutter();
        res_vec = f06_file.read_flutter_eigenvector();
    end
    %assign eigen vectors to modes if they equate
    if opts.IncludeEigenVec
        for i = 1:length(res_vec)
            [~,I] = min(abs([res.CMPLX]-res_vec(i).EigenValue));
            res(I).IDs = res_vec(i).IDs;
            res(I).EigenVector = res_vec(i).EigenVector;
        end
    end
end
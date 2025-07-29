classdef Material < ads.fe.Element
    %MATERIAL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        E = 0
        G = 0;
        rho = 0;
        nu = 0;
        yield = nan;
        ID = nan;
    end
    
    methods
        function obj = Material(E,nu,rho,opts)
            arguments
                E double
                nu double
                rho double
                opts.yield double = nan
                opts.G double = nan
            end
            obj.E = E;
            obj.nu = nu;
            obj.rho = rho;
            if isnan(opts.G)
                obj.G  = E / (2 * (1 + nu));
            else
                obj.G = opts.G;
            end
            obj.yield = opts.yield;
        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).ID = ids.MID;
                ids.MID = ids.MID + 1;
            end
        end
        function Export(obj,fid)
            if ~isempty(obj)
                mni.printing.bdf.writeComment(fid,"MAT1 : Defines the material properties for linear isotropic materials.");
                mni.printing.bdf.writeColumnDelimiter(fid,"long")
                for i = 1:length(obj)
                    tmpCard = mni.printing.cards.MAT1(obj(i).ID,"RHO",obj(i).rho,"NU",obj(i).nu,"G",obj(i).G,"E",obj(i).E);
                    tmpCard.LongFormat = true;
                    tmpCard.writeToFile(fid);
                end
            end
        end
    end
    methods(Static)
        function obj = Aluminium()
            obj = ads.fe.Material(71.7e9,0.33,2810);
            obj.Name = "Aluminium7075";
        end
        function obj = Stainless304()
            obj = ads.fe.Material(193e9,0.29,7930);
            obj.Name = "Stainless304";
        end
        function obj = Stiff()
            obj = ads.fe.Material(inf,0,0);
            obj.Name = "Stiff";
        end
        function obj = FromBaffMat(mat)
            arguments
                mat baff.Material
            end
            obj = ads.fe.Material(mat.E,mat.nu,mat.rho,yield=mat.yield,G=mat.G);
            obj.Name = mat.Name;
        end
    end
end


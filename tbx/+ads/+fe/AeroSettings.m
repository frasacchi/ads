classdef AeroSettings < ads.fe.Element
    %BEAM Summary of this class goes here
    %   Detailed explanation goes here

    properties
        ACSID (1,1) ads.fe.AbsCoordSys = ads.fe.BaseCoordSys.get; 
        RCSID (1,1) ads.fe.AbsCoordSys = ads.fe.BaseCoordSys.get; 
        Velocity double
        RefC double
        RefB double
        RefRho double
        SymXZ = false;
        SymXY = false;

    end

    methods
        function obj = AeroSettings(RefC,RefRho,RefB,opts)
            arguments
                RefC
                RefRho
                RefB
                opts.Velocity (1,1) double = 1;
                opts.ACSID (1,1) ads.fe.AbsCoordSys = ads.fe.BaseCoordSys.get;
                opts.RCSID (1,1) ads.fe.AbsCoordSys = ads.fe.BaseCoordSys.get;
                opts.SymXZ = false;
                opts.SymXY = false;
            end
            obj.Velocity = opts.Velocity;
            obj.RefC = RefC;
            obj.RefB = RefB;
            obj.RefRho = RefRho;
            obj.ACSID = opts.ACSID;
            obj.RCSID = opts.RCSID;
            obj.SymXZ = opts.SymXZ;
            obj.SymXY = opts.SymXY;
        end
        function ids = UpdateID(obj,ids)
        end
        function Export(obj,fid)
            if ~isempty(obj)
                mni.printing.bdf.writeComment(fid,"AERO & AEROS : Defines Aero Properties");
                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                for i = 1:length(obj)
                    mni.printing.cards.AERO(obj(i).RefC,obj(i).RefRho,...
                        ACSID=obj(i).ACSID.ID, VELOCITY=obj(i).Velocity,...
                        SYMXZ=obj(i).SymXZ,SYMXY=obj(i).SymXY).writeToFile(fid);
                    mni.printing.cards.AEROS(obj(i).RefC,obj(i).RefB,obj(i).RefRho,...
                        ACSID=obj(i).ACSID.ID,RCSID=obj(i).RCSID.ID,...
                        SYMXZ=obj(i).SymXZ,SYMXY=obj(i).SymXY).writeToFile(fid);
                end
            end
        end
    end
end


classdef AeroSettings < ads.fe.Element
    %BEAM Summary of this class goes here
    %   Detailed explanation goes here

    properties
        ACSID (1,1) ads.fe.AbsCoordSys = ads.fe.BaseCoordSys.get; 
        RCSID (1,1) ads.fe.AbsCoordSys = ads.fe.BaseCoordSys.get; 
        Velocity double
        RefC double
        RefB double
        RefS double
        RefRho double
        SymXZ = false;
        SymXY = false;

    end

    methods
        function obj = AeroSettings(RefC,RefRho,RefB,RefS,opts)
            arguments
                RefC
                RefRho
                RefB
                RefS
                opts.Velocity (1,1) double = 1;
                opts.ACSID (1,1) ads.fe.AbsCoordSys = ads.fe.BaseCoordSys.get;
                opts.RCSID (1,1) ads.fe.AbsCoordSys = ads.fe.BaseCoordSys.get;
                opts.SymXZ = false;
                opts.SymXY = false;
            end
            obj.Velocity = opts.Velocity;
            obj.RefC = RefC;
            obj.RefB = RefB;
            obj.RefS = RefS;
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
                    acsid = obj(i).ACSID.ID;
                    if acsid == 0
                        acsid = [];
                    end
                    rcsid = obj(i).RCSID.ID;
                    if rcsid == 0
                        rcsid = [];
                    end
                    SYMXZ = obj(i).SymXZ;
                    % if ~SYMXZ
                    %     SYMXZ = [];
                    % end
                    SYMXY = obj(i).SymXY;
                    % if ~SYMXY
                    %     SYMXY = [];
                    % end

                    mni.printing.cards.AERO(obj(i).RefC,obj(i).RefRho,...
                        ACSID=acsid, VELOCITY=obj(i).Velocity,...
                        SYMXZ=SYMXZ,SYMXY=SYMXY).writeToFile(fid);
                    mni.printing.cards.AEROS(obj(i).RefC,obj(i).RefB,obj(i).RefS,...
                        ACSID=acsid,RCSID=rcsid,SYMXZ=SYMXZ,SYMXY=SYMXY).writeToFile(fid);
                end
            end
        end
    end
end


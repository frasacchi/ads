classdef Inertia < ads.fe.Element
    %MASS Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Point ads.fe.Point
        InertiaTensor (6,6) double = zeros(6);
        ID double = nan;
    end

    methods
        function obj = Inertia(InertiaTensor,Point)
            arguments
                InertiaTensor
                Point ads.fe.Point
            end
            %MASS Construct an instance of this class
            %   Detailed explanation goes here
            obj.InertiaTensor = InertiaTensor;
            obj.Point = Point;
        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).ID = ids.EID;
                ids.EID = ids.EID + 1;
            end
        end
        function plt_obj = drawElement(obj)
            arguments
                obj
            end
            if isempty(obj)
                plt_obj = [];
                return
            end
            ps = [obj.Point];
            Xs = [ps.GlobalPos];
            plt_obj = plot3(Xs(1,:),Xs(2,:),Xs(3,:),'m^');
            plt_obj.MarkerFaceColor = 'm';
            plt_obj.Tag = "Inertia";
        end
        function Export(obj,fid)
            if ~isempty(obj)
                mni.printing.bdf.writeComment(fid,"CONM1 : Defines a Generic inertia tensor at a grid point");
                mni.printing.bdf.writeColumnDelimiter(fid,"long")
                for i = 1:length(obj)
                    tmpCard = mni.printing.cards.CONM1(obj(i).ID,obj(i).Point.ID,obj(i).InertiaTensor,...
                        CID=obj(i).Point.InputCoordSys.ID);
                    tmpCard.LongFormat = true;
                    tmpCard.writeToFile(fid);
                end
            end
        end
    end
end


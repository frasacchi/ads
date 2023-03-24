classdef RigidBar < ads.fe.Element
    %BEAM Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Point1 ads.fe.Point
        Point2 ads.fe.Point
        ID double = nan;
    end

    methods
        function obj = RigidBar(point1,point2)
            obj.Point1 = point1;
            obj.Point2 = point2;
        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).ID = ids.EID;
                ids.EID = ids.EID + 1;
            end
        end
        function plt_obj = draw(obj)
            arguments
                obj
            end
            if isempty(obj)
                plt_obj = [];
                return
            end
            for i = 1:length(obj)
                Xs = [obj(i).Point1.GlobalPos,obj(i).Point2.GlobalPos];
                plt_obj(i) = plot3(Xs(1,:),Xs(2,:),Xs(3,:),'m-');
                plt_obj(i).Tag = "RBE";
            end
        end
        function Export(obj,fid)
            if ~isempty(obj)
                mni.printing.bdf.writeComment(fid,"RBE2 : Defines a rigid body with independent DoFs that are specified at a single grid point and with dependent DoFs that are specified at an arbitrary number of grid points.");
                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                for i = 1:length(obj)
                    tmpCard = mni.printing.cards.RBE2(obj(i).ID,obj(i).Point1.ID,123456,obj(i).Point2.ID);
                    tmpCard.writeToFile(fid);
                end
            end
        end
    end
end


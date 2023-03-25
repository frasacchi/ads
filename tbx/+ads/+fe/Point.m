classdef Point   < matlab.mixin.SetGet & ads.fe.Element
    properties
        InputCoordSys = ads.fe.BaseCoordSys.get;
        OutputCoordSys = ads.fe.BaseCoordSys.get;
        X (3,1) double
        DoFs = 123456;
        JointType = ads.fe.JointType.None;
        ID double = nan;
    end
    properties(Dependent)
        GlobalPos
    end
    methods
        function p = get.GlobalPos(obj)
            p = obj.InputCoordSys.getPointGlobal(obj.X);
        end
    end
    methods
        function obj = Point(X,opts)
            arguments
                X (3,1) double
                opts.InputCoordSys ads.fe.AbsCoordSys = ads.fe.BaseCoordSys.get;
                opts.OutputCoordSys ads.fe.AbsCoordSys = ads.fe.BaseCoordSys.get;
                opts.DoFs = 123456
                opts.JointType = ads.fe.JointType.None;
            end
            %POINT Construct an instance of this class
            %   Detailed explanation goes here
            obj.X = X;
            obj.InputCoordSys = opts.InputCoordSys;
            obj.OutputCoordSys = opts.OutputCoordSys;
            obj.DoFs = opts.DoFs;
            obj.JointType = opts.JointType;
        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).ID = ids.GID;
                ids.GID = ids.GID + 1;
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
            Xs = [obj.GlobalPos];
            plt_obj = plot3(Xs(1,:),Xs(2,:),Xs(3,:),'go');
            plt_obj.MarkerFaceColor = 'g';
            plt_obj.Tag = "Node";
        end
        function Export(obj,fid)
            if ~isempty(obj)
                mni.printing.bdf.writeComment(fid,"GRID : Defines the location of a geometric grid point, the directions of its displacement, and its permanent single-point constraints.");
                mni.printing.bdf.writeColumnDelimiter(fid,"long")
                for i = 1:length(obj)
                    tmpCard = mni.printing.cards.GRID(obj(i).ID,obj(i).X,...
                        "CP",obj(i).InputCoordSys.ID,"CD",obj(i).OutputCoordSys.ID);
                    tmpCard.LongFormat = true;
                    tmpCard.writeToFile(fid);
                end
            end
        end
    end
end


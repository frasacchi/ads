classdef Point   < matlab.mixin.SetGet & ads.fe.Element
    properties
        InputCoordSys = ads.fe.BaseCoordSys.get;
        OutputCoordSys = ads.fe.BaseCoordSys.get;
        X (3,1) double
        isAttachmentPoint = true; % can children attach to this point
        isAnchorPoint = true; % can parents attach to this point
        ExportinGlobal = false; % when true the point is exported in the global coordinate system (when written to a bdf file)
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
                opts.isAnchor = true;
                opts.isAttachment = true;
            end
            %POINT Construct an instance of this class
            %   Detailed explanation goes here
            obj.X = X;
            obj.InputCoordSys = opts.InputCoordSys;
            obj.OutputCoordSys = opts.OutputCoordSys;
            obj.isAnchorPoint = opts.isAnchor;
            obj.isAttachmentPoint = opts.isAttachment;
        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).ID = ids.GID;
                ids.GID = ids.GID + 1;
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
                    if ~obj(i).ExportinGlobal
                        tmpCard = mni.printing.cards.GRID(obj(i).ID,obj(i).X,...
                            "CP",obj(i).InputCoordSys.ID,"CD",obj(i).OutputCoordSys.ID);
                    else
                        tmpCard = mni.printing.cards.GRID(obj(i).ID,obj(i).GlobalPos,...
                            "CD",obj(i).OutputCoordSys.ID);
                    end
                    tmpCard.LongFormat = true;
                    tmpCard.writeToFile(fid);
                end
            end
        end
    end
end


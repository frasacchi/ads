classdef RigidBodyElement < ads.fe.Element
    %BEAM Summary of this class goes here
    %   Detailed explanation goes here

    properties
        %Point1 ads.fe.Point
        %Point2 ads.fe.Point
        EID double = nan;
        REFGRID double = nan;
        REFC (:,1) double {mustBeInteger,mustBePositive}
        WTi (:,1) double {mustBeNumeric,mustBePositive}
        Ci (:,1) double {mustBeInteger,mustBePositive}
        Gi %(:,1) double {mustBeInteger,mustBePositive}
        ExportLongFormat logical = true;
    end

    methods
        function obj = RigidBodyElement(EID,REFGRID,REFC,WTi,Ci,Gi)
            arguments
               EID double
               REFGRID double
               REFC double
               WTi (:,1) double
               Ci (:,1) double
               Gi %(:,1) double
            end
            obj.EID=EID;
            obj.REFGRID=REFGRID;
            obj.REFC=REFC;
            obj.WTi = WTi;
            obj.Ci = Ci;
            if length(Ci)~=length(Gi)
                error('Gi Ci not same length')
            end
            obj.Gi = Gi;

        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).ID = ids.EID;
                ids.EID = ids.EID + 1;
            end
        end
        % function plt_obj = drawElement(obj)
        %     arguments
        %         obj
        %     end
        %     if isempty(obj)
        %         plt_obj = [];
        %         return
        %     end
        %     for i = 1:length(obj)
        %         Xs = [obj(i).Point1.GlobalPos,obj(i).Point2.GlobalPos];
        %         plt_obj(i) = plot3(Xs(1,:),Xs(2,:),Xs(3,:),'m-');
        %         plt_obj(i).Tag = "RBE";
        %     end
        % end
        
        
        function Export(obj,fid)
            obj(1).ExportToRBE3(fid);
        end

        function ExportToRBE3(obj,fid)

            if ~isempty(obj)
                % print CBEAM elements
                mni.printing.bdf.writeComment(fid,"RBE3: Defines an MPC element.");
                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                for i = 1:length(obj)
                    %Pa = obj(i).Stations(1).Point;
                    %Pb = obj(i).Stations(end).Point;
                    % if ~isempty(obj(i).G0)
                        %tmpCard = mni.printing.cards.CBEAM(obj(i).ID,obj(i).PID,Pa.ID,Pb.ID,"G0",obj(i).G0.ID);
                        %EID,REFGRID,REFC,WTi,Ci,Gij,
                        
                        
                        %RBE3 fancy things live here 

                        tmpCard = mni.printing.cards.RBE3(obj(i).EID,obj(i).REFGRID,obj.REFC,obj.WTi,obj.Ci,obj.GIj);
                        
                    % else
                    %     tmpCard = mni.printing.cards.CBEAM(obj(i).ID,obj(i).PID,Pa.ID,Pb.ID,"x",obj(i).yDir);
                    % end
                    tmpCard.writeToFile(fid);
                end
                % print PBEAM elements
                % mni.printing.bdf.writeComment(fid,"PSHELL : Defines the properties of a SHELL element.");
                % mni.printing.bdf.writeColumnDelimiter(fid,"long")
                % % for i = 1:length(obj)
                % %     % create matran sections
                % %     matSecs = mni.printing.cards.BeamSection.empty;
                % %     Xa = obj(i).Stations(1).Point.X;
                % %     Xb = obj(i).Stations(end).Point.X;
                % %     for j = 1:length(obj(i).Stations)
                % %         matSecs(j) = obj(i).Stations(j).ToMatranSection(Xa,Xb);
                % %     end
                %     %print PBEAM cards
                %     %tmpCard = mni.printing.cards.PBEAM(obj(i).PID,obj(i).Stations(1).Mat.ID,matSecs,K=[1,1]*obj(i).K);
                %     tmpCard = mni.printing.cards.PSHELL(obj(i).PID,obj(i).Mat,obj(i).Thickness,obj(i).Mat,[],obj(i).Mat);
                %     tmpCard.LongFormat = obj.ExportLongFormat;
                %     tmpCard.writeToFile(fid);
                % end
            end
        end












        
        % function Export(obj,fid)
        %     if ~isempty(obj)
        %         mni.printing.bdf.writeComment(fid,"RBE2 : Defines a rigid body with independent DoFs that are specified at a single grid point and with dependent DoFs that are specified at an arbitrary number of grid points.");
        %         mni.printing.bdf.writeColumnDelimiter(fid,"short")
        %         for i = 1:length(obj)
        %             tmpCard = mni.printing.cards.RBE2(obj(i).ID,obj(i).Point1.ID,123456,obj(i).Point2.ID);
        %             tmpCard.writeToFile(fid);
        %         end
        %     end
        % end
    end
end


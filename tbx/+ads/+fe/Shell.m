classdef Shell < ads.fe.Element
    %BEAM Summary of this class goes here
    %   Detailed explanation goes here

    % - TODO- Thickness must equal sum of ply layers 'T'
    properties
        EID double = nan;
        PID double = nan;
        G ads.fe.Point=ads.fe.Point.empty(0,1);
        Mat ads.fe.Material = ads.fe.Material.empty;
        Thickness double {mustBePositive}= 1e-6;

        ExportType string {mustBeMember(ExportType,{'PCOMP','PSHELL'})} = "PSHELL";        
        ply ads.fe.PlyDefinition = ads.fe.PlyDefinition;
        ExportLongFormat logical = false; %maybe true
    end

    methods
        function obj = Shell(G,Mat,Thickness,opts)
            arguments
                G (4,1) ads.fe.Point
                Mat ads.fe.Material 
                Thickness double
                opts.ply ads.fe.PlyDefinition = ads.fe.PlyDefinition;
                opts.ExportType string {mustBeMember(opts.ExportType,{'PCOMP','PSHELL'})} = "PSHELL";
            end
            obj.G=G;
            obj.Mat = Mat;
            obj.Thickness = Thickness;
            obj.ply = opts.ply;
            obj.ExportType = opts.ExportType;
        end

        % - TODO -- shell mass estimation not implemented
        function m = GetMass(obj)
            m = zeros(size(obj));
            warning('shell mass estimation not implemented')
        end

        function plt_obj = drawElement(obj)
            arguments
                obj
            end
            if isempty(obj)
                plt_obj = [];
                return
            end
            for i = 1:length(obj)
                nodes = [obj(i).G];
                Xs = [nodes.GlobalPos];
                if obj(i).ExportType == "PCOMP"
                    plt_obj(i) = patch(Xs(1,:),Xs(2,:),Xs(3,:),'r');
                    plt_obj(i).EdgeColor = 'r';
                    plt_obj(i).FaceAlpha = 0.6;
                    plt_obj(i).Tag = "CQUAD4(PCOMP)";
                elseif obj(i).ExportType == "PSHELL"
                    plt_obj(i) = plot3(Xs(1,:),Xs(2,:),Xs(3,:),'k');
                    plt_obj(i).Tag = "CQUAD4(PSHELL)";
                end
            end
        end

        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).EID = ids.EID;
                ids.EID = ids.EID + 1;
                obj(i).PID = ids.PID;
                ids.PID = ids.PID + 1;
            end
        end

        function Export(obj,fid)
            if ~isempty(obj)
                % print CQUAD4 elements
                mni.printing.bdf.writeComment(fid,"CQUAD4: Defines a QUADRILATERAL element.");
                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                for i = 1:length(obj)
                    tmpCard = mni.printing.cards.CQUAD4(obj(i).EID,obj(i).PID,[obj(i).G.ID]);
                    tmpCard.writeToFile(fid);
                end

                % print PCOMP/PSHELL elements
                names = ["PCOMP","PSHELL"];
                for i = 1:length(names)
                    idx= [obj.ExportType] == names(i);
                    if nnz(idx)>0
                        switch names(i)
                            case "PCOMP"
                                obj(idx).ExportToPCOMP(fid);
                            case "PSHELL"
                                obj(idx).ExportToPSHELL(fid);
                        end
                    end
                end
            end
        end

        function ExportToPCOMP(obj,fid)
            % print PCOMP elements
            mni.printing.bdf.writeComment(fid,"PCOMP : Defines the properties of an n-ply composite material laminate.");
            mni.printing.bdf.writeColumnDelimiter(fid,"long")
            for i = 1:length(obj)

                plyLayers = mni.printing.cards.PlyLayer.empty;
                for j = 1:length(obj(i).ply.Layers)
                    plyLayers(j) = obj(i).ply.Layers(j).ToMatran();
                end

                tmpCard = mni.printing.cards.PCOMP(obj(i).PID,obj(i).ply.Z0,obj(i).ply.NSM,obj(i).ply.SB,obj(i).ply.FT,obj(i).ply.TREF,obj(i).ply.GE,obj(i).ply.LAM,plyLayers);

                tmpCard.LongFormat = obj.ExportLongFormat;
                tmpCard.writeToFile(fid);
            end
        end

        function ExportToPSHELL(obj,fid)
            % print PSHELL elements
            mni.printing.bdf.writeComment(fid,"PSHELL : Defines the properties of a SHELL element.");
            mni.printing.bdf.writeColumnDelimiter(fid,"long")
            for i = 1:length(obj)
                tmpCard = mni.printing.cards.PSHELL(obj(i).PID,obj(i).Mat.ID,obj(i).Thickness,obj(i).Mat.ID,[],obj(i).Mat.ID);
                tmpCard.LongFormat = obj.ExportLongFormat;
                tmpCard.writeToFile(fid);

            end
        end

        function obj = FromBaffStations(st,G,Mat,Thickness)
            arguments
                st baff.station.ShellStation.Shell
                G(4,1) ads.fe.Point
                Mat ads.fe.Material
                Thickness double
            end

            if st.ExportType == "PCOMP" 
                PlyDef = ads.fe.PlyDefinition.FromBaffStation(st.ply);
            elseif st.ExportType == "PSHELL" 
                PlyDef = ads.fe.PlyDefinition.empty;
            end

            obj = ads.fe.Shell(G,Mat,Thickness,"ExportType",st.ExportType,"ply",PlyDef);

        end

    end

end


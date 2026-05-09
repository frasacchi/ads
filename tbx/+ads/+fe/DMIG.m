classdef DMIG < ads.fe.Element
    %BEAM Summary of this class goes here
    %   Detailed explanation goes here

    properties
        IFO
        TIN = 1; % 1 = Real Single Precision
        TOUT = 0;
        GJ ads.fe.Point=ads.fe.Point.empty(0,1);
        CJ;
        Gs;
        Cs;
        As;
        Bs;
        ExportLongFormat logical = true;
        N;
    end

    methods
        function obj = DMIG(Name, IFO, TIN, TOUT, GJ, CJ, Gs, Cs, As, Bs)
            if nargin == 0
                return;
            end
            obj.Name = Name;
            obj.IFO = IFO;
            obj.TIN = TIN;
            obj.TOUT = TOUT;
            obj.GJ = GJ;
            obj.CJ = CJ;
            obj.Gs = Gs;
            obj.Cs = Cs;
            obj.As = As;
            obj.Bs = Bs;
            obj.N = length(GJ);
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
                ps = vertcat(obj.GJ,vertcat(obj.Gs{:}));
                Xs = [ps.GlobalPos];
                plt_obj(i) = plot3(Xs(1,:),Xs(2,:),Xs(3,:),'*r');
                plt_obj(i).MarkerFaceColor = [0.3,0.3,0.3];
                plt_obj(i).Tag = "DMIG";
            end
        end

        function Export(obj,fid)

            for i=1:numel(obj)
                mni.printing.bdf.writeComment(fid,"DMIG : Direct Matrix Input at Points");
                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                tmpCard = mni.printing.cards.DMIG(obj.Name, obj.IFO, obj.TIN, obj.GJ, obj.CJ, obj.Gs, obj.Cs, obj.As, obj.Bs);
                tmpCard.writeToFile(fid);
            end
            
        end

    end
    methods(Static)

        function obj = FromBaffStations(sts,ps)
            arguments
                sts baff.station.Beam
                ps (:,1) ads.fe.Point
            end

            dmig =sts.DMIG;
            if isempty(dmig)
                obj = ads.fe.DMIG.empty(0,1);
                return;
            end
            
            nConditions = size(dmig,1);
            nPoints = size(dmig,2);
            
            for i = 1:nConditions
                dmig_i = dmig(i,:);
                for j=1:nPoints
                CJ(j) = dmig_i(j).DOFs(1);
                Gs{j} = ps(dmig_i(j).idx);
                Cs{j} = repmat(dmig_i(j).DOFs(2:end), 1, length(dmig_i(j).idx));
                end
                As = {dmig_i.A};

                %tmp % TODO TIN & TOUT
                Bs = [];

                % Populate the object
                obj(i) = ads.fe.DMIG(dmig_i(1).Name, dmig_i(1).IFO, 1, 0, ps([dmig_i.idx0]), CJ, Gs, Cs, As, Bs);
            end

        end
    end
end


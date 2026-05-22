function [K] = PTDF(branch,bus,BS,nl,nb,ns)

K = zeros(nl,nb,ns);
for i=1:ns
    il = find(BS(i,:)==1);
    nl1 = length(il);
    tembranch = branch(il,:);
    fb=tembranch(:,1);
    tb=tembranch(:,2);
    Cf = sparse(fb, 1:nl1, ones(nl1, 1), nb, nl1);
    Ct = sparse(tb, 1:nl1, ones(nl1, 1), nb, nl1);
    Yl = 1./tembranch(:,4);
    BF =(Cf-Ct)'.*Yl;  %nl*nb   电纳关系
    BN = Cf * spdiags(Yl, 0, nl1, nl1) * Cf' + ...	%% Yff term of branch admittance
        Cf * spdiags(-Yl, 0, nl1, nl1) * Ct' + ...	%% Yft term of branch admittance
        Ct * spdiags(-Yl, 0, nl1, nl1) * Cf' + ...	%% Ytf term of branch admittance
        Ct * spdiags(Yl, 0, nl1, nl1) * Ct';			%% Ytt term of branch admittance
    %参考节点
    AllreadyProcessBus = zeros(size(bus,1),1);
%     AllreadyProcessBranch =zeros(nl1,1);
        AllreadyProcessBranch = 1-BS(i,:)';
    sinbus = [];
    while isempty(find(AllreadyProcessBus == 0)) == 0 %等于零的是没有评估的支路（主网络可能分成几块，一块一块评估）
        [nodehao,branchhao] = AnalylizedSepartedNet(bus,tembranch,AllreadyProcessBus,AllreadyProcessBranch);
        AllreadyProcessBus(nodehao) = 1;
        AllreadyProcessBranch(branchhao)  = 1;
        if length(nodehao)==1
            sinbus=[sinbus;nodehao];
        else
            refbus=nodehao(1);
            BN(refbus,refbus)=0;
        end
    end
    sinbus=sort(sinbus,'descend');
    for j = 1:size(sinbus,1)
        BN(sinbus(j),:) = [];
        BN(:,sinbus(j)) = [];
        BF(:,sinbus(j)) = [];
    end
    Ks = zeros(nl1,nb);
    cobus = setdiff(1:nb,sinbus);
    Ks(:,cobus)=full(BF/BN);
    K(il,:,i) = Ks;
end
end


% B = [20 -10 -10
%     -10 15 -5
%     -10 -5 15];
% B1=[10 -10 0
%     10 0 -10
%     0 5 -5];
% B2=B1/B;
% I=[15;5;-20];
% F=B2*I;






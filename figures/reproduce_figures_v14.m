function reproduce_figures_v14()
% Audit reproduction of Figures 1-8 from the V14 manuscript.
% Uses archived CSV summaries, not retraining or new policy evaluation.
% MATLAB R2024b; no add-on toolbox required. Run from figures/.
root = fileparts(mfilename('fullpath'));
data = fullfile(root,'..','results'); out = fullfile(root,'output');
if ~isfolder(out), mkdir(out); end
P = readtable(fullfile(data,'primary_run_ledger.csv'),'TextType','string');
Q = readtable(fullfile(data,'paired_primary_recomputed.csv'),'TextType','string');
A = readtable(fullfile(data,'ablation_run_matrix_36.csv'),'TextType','string');
B = readtable(fullfile(data,'paired_ablation_recomputed.csv'),'TextType','string');
M = readtable(fullfile(data,'figure7_metrics.csv'),'TextType','string');
algs = ["DDPG","TD3","SAC"]; arms = ["PG","GF"];
assert(height(P)==30 && height(Q)==7 && height(A)==36 && height(B)==25);
assert(isequal(sum(str2double(string(P.highest_mastered(P.arm=="PG")))==10),13));
assert(isequal(sum(str2double(string(P.highest_mastered(P.arm=="GF")))==10),9));

% Figure 1: conceptual diagram. Its contents are a schematic, not measured data.
f=figure('Color','w','Position',[80 80 1250 530]); ax=axes(f,'Position',[0 0 1 1]);axis(ax,'off');
boxtext(.02,.34,.20,.32,"Physical/mission knowledge"+newline+"speed, obstacles, goal, stages",[.87 .92 .97]);
boxtext(.28,.34,.24,.32,"Task formulation"+newline+"PG: four physical rules"+newline+"GF: fixed counterparts",[.83 .91 .98]);
boxtext(.58,.34,.17,.32,"Shared plant and interface"+newline+"DDPG | TD3 | SAC",[.91 .94 .96]);
boxtext(.81,.52,.17,.17,"Trainability"+newline+"mastery; interactions",[.88 .95 .88]);
boxtext(.81,.27,.17,.17,"Conditional deployment"+newline+"success; behavior",[.96 .92 .82]);
annotation(f,'arrow',[.22 .28],[.5 .5]);annotation(f,'arrow',[.52 .58],[.5 .5]);
annotation(f,'arrow',[.75 .81],[.52 .60]);annotation(f,'arrow',[.75 .81],[.47 .35]);
annotation(f,'textbox',[.02 .78 .95 .12],'String','Figure 1 — study architecture (schematic; PG/GF comparison)','EdgeColor','none','FontSize',17,'FontWeight','bold');
savefig(f,out,1);close(f);

% Figure 2: illustrative geometry; obstacles are schematic, not bank members.
f=figure('Color','w','Position',[80 80 1200 530]);t=tiledlayout(f,1,2,'Padding','compact');
ax=nexttile(t);hold(ax,'on');axis(ax,'equal');xlim(ax,[0 20]);ylim(ax,[0 20]);grid(ax,'on');
for o=[5 5 1.5;10 8 1.8;8 14 1.2;15 12 1.3]'
    rectangle(ax,'Position',[o(1)-o(3),o(2)-o(3),2*o(3),2*o(3)],'Curvature',[1 1],'FaceColor',[.93 .95 .96]);
end
plot(ax,1,1,'o','MarkerFaceColor',[.15 .48 .74]);plot(ax,8,6,'s','MarkerFaceColor',[.2 .65 .35]);
plot(ax,18,18,'p','MarkerFaceColor',[.9 .5 .1]);
text(ax,1.5,1.4,'start');text(ax,8.4,6.3,'vehicle');text(ax,16,18.6,'goal');
xlabel(ax,'World x (m)');ylabel(ax,'World y (m)');title(ax,'(a) Illustrative planar testbed');
ax=nexttile(t);hold(ax,'on');axis(ax,'equal');xlim(ax,[-2 5]);ylim(ax,[-2 5]);grid(ax,'on');
eg=[10;12]/norm([10;12]);el=[-eg(2);eg(1)];
quiver(ax,0,0,3*eg(1),3*eg(2),0,'LineWidth',2);quiver(ax,0,0,2*el(1),2*el(2),0,'LineWidth',2);
u=2*eg+.7*el;quiver(ax,0,0,u(1),u(2),0,'LineWidth',2,'Color',[.15 .15 .15]);
text(ax,3*eg(1),3*eg(2),'e parallel');text(ax,2*el(1),2*el(2),'e perpendicular');
text(ax,u(1),u(2),'E_g u');xlabel(ax,'World x direction');ylabel(ax,'World y direction');title(ax,'(b) Goal-relative action frame');
savefig(f,out,2);close(f);

% Figure 3: four frozen task rules. Values are the historical configuration.
f=figure('Color','w','Position',[80 80 1200 750]);t=tiledlayout(f,2,2,'Padding','compact');
ax=nexttile(t);d=linspace(0,4,400);pg=min(2,sqrt(2*max(d-.5,0)));
plot(ax,d,pg,'LineWidth',2);hold(ax,'on');yline(ax,2,'--');grid(ax,'on');
xlabel(ax,'Goal distance (m)');ylabel(ax,'Reference speed (m/s)');title(ax,'(a) Braking-aware speed');legend(ax,'PG','GF');
ax=nexttile(t);v=linspace(0,2,400);plot(ax,v,min(2.5,.5+v.^2/2),'LineWidth',2);hold(ax,'on');yline(ax,.5,'--');grid(ax,'on');
xlabel(ax,'Closing speed (m/s)');ylabel(ax,'Warning clearance (m)');title(ax,'(b) Dynamic warning');legend(ax,'PG','GF');
s=1:10;r=[1.5 1 .75 .75 1 .5 .5 .5 .5 .5];h=[100 120 150 180 180 300 300 300 300 300];
ax=nexttile(t);plot(ax,s,r,'-o',s,r,'--s','LineWidth',1.6);hold(ax,'on');yline(ax,.5,':');grid(ax,'on');
xlabel(ax,'Stage');ylabel(ax,'Radius (m) / speed limit (m/s)');title(ax,'(c) Terminal curriculum');legend(ax,'Radius','Arrival speed','GF');
ax=nexttile(t);plot(ax,s,h,'-o','LineWidth',1.6);hold(ax,'on');yline(ax,300,'--');grid(ax,'on');
xlabel(ax,'Stage');ylabel(ax,'Episode horizon (steps)');title(ax,'(d) Stage horizon');legend(ax,'PG','GF');
savefig(f,out,3);close(f);

% Figure 4: protocol chronology. The comparator freeze followed PG MS01-03.
f=figure('Color','w','Position',[80 80 1250 500]);axes(f,'Position',[0 0 1 1]);axis off;
boxtext(.03,.42,.20,.25,"PG MS01–MS03"+newline+"screening observed",[.83 .91 .98]);
boxtext(.28,.42,.20,.25,"Freeze GF comparator"+newline+"and evaluation rules",[.97 .91 .78]);
boxtext(.53,.42,.20,.25,"PG MS04–MS05"+newline+"then GF MS01–MS05",[.83 .91 .98]);
boxtext(.78,.42,.19,.25,"30 training runs"+newline+"qualification",[.88 .95 .88]);
for x=[.23 .48 .73],annotation(f,'arrow',[x x+.05],[.54 .54]);end
annotation(f,'textbox',[.03 .82 .94 .1],'String','Figure 4 — paired protocol and comparator freeze (schematic)','EdgeColor','none','FontSize',17,'FontWeight','bold');
annotation(f,'textbox',[.19 .15 .65 .12],'String','Only qualified policies enter the common 100-scenario nominal final test. Failed training runs remain failures.','EdgeColor','none','HorizontalAlignment','center','FontSize',12);
savefig(f,out,4);close(f);

% Figure 5: exact seed-level mastery status from audited run ledger.
f=figure('Color','w','Position',[80 80 1150 580]);ax=axes(f);hold(ax,'on');
labels=strings(6,1);k=0;
for i=1:3
 for j=1:2
  k=k+1;labels(k)=algs(i)+" "+arms(j);
  for seed=1:5
   row=P(P.algorithm==algs(i)&P.arm==arms(j)&P.seed==seed,:);
   assert(height(row)==1);pass=str2double(string(row.highest_mastered))==10;
   if pass,c=[.19 .48 .75];else,c=[.88 .89 .90];end
   rectangle(ax,'Position',[seed-.43,6-k+.55,.86,.8],'FaceColor',c,'EdgeColor',[.55 .55 .55]);
   if pass,sym='✓';else,sym='×';end
   text(ax,seed,7-k,sym,'HorizontalAlignment','center','FontSize',18,'FontWeight','bold');
  end
 end
end
xlim(ax,[.4 5.6]);ylim(ax,[.4 6.6]);xticks(ax,1:5);xticklabels(ax,"MS0"+string(1:5));
yticks(ax,1:6);yticklabels(ax,flip(labels));grid(ax,'off');title(ax,'Figure 5 — Stage-10 qualification by paired seed');
savefig(f,out,5);close(f);

% Figure 6: cost of mastery only when both paired arms qualified.
f=figure('Color','w','Position',[80 80 1200 600]);t=tiledlayout(f,1,2,'TileSpacing','compact');
ax=nexttile(t);hold(ax,'on');labs=strings(height(Q),1);
for i=1:height(Q)
 y=height(Q)+1-i;plot(ax,[Q.PG(i),Q.GF(i)],[y,y],'-','Color',[.72 .75 .78],'LineWidth',2);
 plot(ax,Q.PG(i),y,'o','MarkerFaceColor',[.16 .48 .72],'MarkerEdgeColor',[.16 .48 .72]);
 plot(ax,Q.GF(i),y,'o','MarkerFaceColor',[.65 .67 .69],'MarkerEdgeColor',[.65 .67 .69]);
 labs(i)=Q.algorithm(i)+" MS"+sprintf('%02d',Q.seed(i));
end
yticks(ax,1:height(Q));yticklabels(ax,flip(labs));ylim(ax,[.5 height(Q)+.75]);
xlabel(ax,'Interactions to Stage-10 mastery');
title(ax,'(a) Seven jointly qualified pairs');grid(ax,'on');
hPG=plot(ax,nan,nan,'o','MarkerFaceColor',[.16 .48 .72],'MarkerEdgeColor',[.16 .48 .72]);
hGF=plot(ax,nan,nan,'o','MarkerFaceColor',[.65 .67 .69],'MarkerEdgeColor',[.65 .67 .69]);
legend(ax,[hPG hGF],{'PG','GF'},'Location','southeast');
ax=nexttile(t);axis(ax,'off');
text(ax,.05,.82,'(b) Nonqualified runs','FontWeight','bold','Units','normalized');
for i=1:3
 pg=sum(P.algorithm==algs(i)&P.arm=="PG"&str2double(string(P.highest_mastered))<10);
 gf=sum(P.algorithm==algs(i)&P.arm=="GF"&str2double(string(P.highest_mastered))<10);
 text(ax,.05,.72-(i-1)*.23,sprintf('%s: PG %d/5 | GF %d/5',algs(i),pg,gf),'Units','normalized','FontSize',12);
end
savefig(f,out,6);close(f);

% Figure 7: final-test success plus behavior conditional on successful episodes.
f=figure('Color','w','Position',[80 80 1200 760]);t=tiledlayout(f,2,2,'Padding','compact');
ax=nexttile(t,[1 2]);hold(ax,'on');labs=strings(height(Q),1);
for i=1:height(Q)
 plot(ax,i-.08,Q.PG_success(i),'o','MarkerFaceColor',[.16 .48 .72],'MarkerEdgeColor',[.16 .48 .72]);
 plot(ax,i+.08,Q.GF_success(i),'s','MarkerFaceColor',[.95 .52 .18],'MarkerEdgeColor',[.95 .52 .18]);
 labs(i)=Q.algorithm(i)+" MS"+sprintf('%02d',Q.seed(i));
end
xticks(ax,1:height(Q));xticklabels(ax,labs);ylim(ax,[70 102]);ylabel(ax,'Final-test success (%)');grid(ax,'on');title(ax,'(a) Paired-qualified policies, 100 scenarios each');
hPG=plot(ax,nan,nan,'o','MarkerFaceColor',[.16 .48 .72],'MarkerEdgeColor',[.16 .48 .72]);
hGF=plot(ax,nan,nan,'s','MarkerFaceColor',[.95 .52 .18],'MarkerEdgeColor',[.95 .52 .18]);
legend(ax,[hPG hGF],{'PG','GF'},'Location','southwest');
ax=nexttile(t);names=["pathLength","directness","minimumClearance","controlEffort","actionVariation","actionSaturationRate"];
v=zeros(1,numel(names));
for i=1:numel(names)
 p=metric(M,"DDPG","PG",4,names(i)+"_success");
 g=metric(M,"DDPG","GF",4,names(i)+"_success");v(i)=100*(p-g)/g;
end
barh(ax,v);yticks(ax,1:numel(names));yticklabels(ax,["Path length","Directness","Min clearance","Control effort","Action variation","Saturation"]);
xlabel(ax,'PG–GF relative change (%)');title(ax,'(b) DDPG MS04 descriptive behavior');grid(ax,'on');
xlim(ax,[-100 110]);
ax=nexttile(t);axis(ax,'off');
text(ax,.03,.91,'(c) TD3 / SAC secondary behavior','Units','normalized','FontWeight','bold');
j=0;
for i=1:height(Q)
 if Q.algorithm(i)=="DDPG",continue;end
 j=j+1;
 p=metric(M,Q.algorithm(i),"PG",Q.seed(i),"minimumClearance_success");
 g=metric(M,Q.algorithm(i),"GF",Q.seed(i),"minimumClearance_success");
 line=sprintf('%s MS%02d: min clearance PG %.3f m; GF %.3f m',Q.algorithm(i),Q.seed(i),p,g);
 text(ax,.03,.82-(j-1)*.12,line,'Units','normalized','FontSize',9);
end
text(ax,.03,.055,'Behavioral means: successful episodes. SAC saturation: structural zero.', ...
 'Units','normalized','FontSize',8);
savefig(f,out,7);close(f);

% Figure 8: completed ablations vs matched historical Full-PG controls.
f=figure('Color','w','Position',[80 80 1200 600]);t=tiledlayout(f,1,2,'Padding','compact');
ax=nexttile(t);hold(ax,'on');abls=["A1","A2","A3","A4"];
counts=zeros(4,3);available=zeros(4,3);
for i=1:4
 for j=1:3
  rows=A(A.arm==abls(i)&A.algorithm==algs(j),:);
  available(i,j)=sum(~contains(lower(rows.status),"censor"));
  counts(i,j)=sum(str2double(string(rows.highest_mastered))==10 & ~contains(lower(rows.status),"censor"));
  text(ax,j,5-i,sprintf('%d/%d',counts(i,j),available(i,j)),'HorizontalAlignment','center','FontSize',13);
 end
end
xlim(ax,[.5 3.5]);ylim(ax,[.5 4.5]);xticks(ax,1:3);xticklabels(ax,algs);
yticks(ax,1:4);yticklabels(ax,flip(abls));grid(ax,'on');
title(ax,'(a) Stage-10 mastery; Full-PG 3/3 each');
xlabel(ax,'SAC A1: 2/2 completed + 1 infrastructure-censored');
ax=nexttile(t);signed=zeros(4,1);absolute=zeros(4,1);
for i=1:4
 vals=B.delta_pct(B.ablation==abls(i));signed(i)=median(vals);absolute(i)=median(abs(vals));
end
barh(ax,[signed absolute]);yticks(ax,1:4);yticklabels(ax,abls);
xlabel(ax,'Interaction-cost change (%)');legend(ax,'Median signed','Median absolute');
title(ax,'(b) Clean paired-mastered comparisons');grid(ax,'on');
savefig(f,out,8);close(f);

fprintf('Created Figure_01 through Figure_08 PNG files in %s\n',out);
end

function boxtext(x,y,w,h,str,color)
annotation('textbox',[x y w h],'String',str,'HorizontalAlignment','center', ...
 'VerticalAlignment','middle','FontSize',11,'LineWidth',1,'BackgroundColor',color);
end
function val=metric(T,alg,arm,seed,name)
row=T(T.algorithm==alg&T.arm==arm&T.seed==seed,:);
assert(height(row)==1 && ismember(name,string(T.Properties.VariableNames)));
val=row.(char(name));
end
function savefig(f,out,n)
exportgraphics(f,fullfile(out,sprintf('Figure_%02d_audit.png',n)),'Resolution',220);
end

# vim: set ft=nroff:syntax=nroff
{
  pkgs,
  lib ? pkgs.lib,
  ...
}:

let
  config = import ./config.enc.nix;

  renderDescription = experience: lib.concatMapStringsSep "\n" (item:
    if (builtins.isList item) then
      ''
      .Bl 
      ${ renderDescription item }
      .El
      ''
    else
      ''
      .It
      ${item}
      ''
    ) experience;
in
''
.Dd 20th October 2026
.Dt DCURGZ.ME 7
.Os @nix-gitrev@
.Sh NAME
.Nm ${config.firstName} ${config.lastName}
.Nd ${config.title}
.Sh CONTACT
.Pp
<b>E:</b> ${config.plusEmail}
.Pp
Please see my CV for my telephone number and LinkedIn profile.
.Sh EDUCATION
.Bl
.It
.Bf Sy -emphasis
${config.education.university.degree}
.Ef
.Pp
${config.education.university.name}
.Bq ${config.education.university.date}
.Pp 
.Bf Sy -emphasis
Achieved:
.Ef
${config.education.university.achieved}
.Pp
.It
.Bf Sy -emphasis
A-Level College
.Ef
.Pp
${config.education.college.name}
.Bq ${config.education.college.date}
.Pp
.Bf Sy -emphasis
Subjects:
.Ef
${config.education.college.subjects}
.Pp
.Bf Sy -emphasis
Achieved:
.Ef
${config.education.college.achieved}
.El
.Sh EXPERIENCE
.Bl
${ lib.concatMapStringsSep "\n" (job:
''
.It
.Bf Sy -emphasis
${job.company}
.Ef
.Bq ${job.date}
.Pp
${ builtins.concatStringsSep ", " job.roles}
.Pp
.Bf Sy -emphasis
Technologies:
.Ef
${ builtins.concatStringsSep ", " job.tags}
.Pp
.Bl
${ renderDescription job.longDescription }
.El
'') config.experience }
.El
.Sh PERSONAL PROJECTS

.Bl
${ lib.concatMapStringsSep "\n" (project:
''
.It
.Bf Sy -emphasis
.Lk ${project.link} ${project.name}
.Ef
.Pq ${project.date}
\(Em
.Dq ${project.tagline}
.Pp
${project.description}
'') config.projects }
.El
''

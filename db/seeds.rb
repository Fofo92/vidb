puts "Cleaning database..."
Gender.destroy_all
Gender.connection.execute('ALTER SEQUENCE genders_id_seq RESTART WITH 1')

puts "Creating Genders..."
Gender.create!({
  name: "Comédie",
  comment: "Genre cinématographique fonctionnant le plus généralement sur le registre comique (divertissement, légèreté, rire, etc.)"
  })
Gender.create!({
  name: "Drame",
  comment: "Genre cinématographique qui traite des situations dans un contexte sérieux, sur un ton plus susceptible d'inspirer la tristesse que le rire. Il évoque étymologiquement l'action."
  })
Gender.create!({
  name: "Romance",
  comment: "Genre cinématographique qui s'appuie sur une histoire d'amour, mettant en avant la passion, les émotions et l'engagement affectif des personnages principaux."
  })
Gender.create!({
  name: "Policier",
  comment: "Genre cinématographique qui regroupe des œuvres qui mettent en scène le milieu du crime ou de la police. "
  })
Gender.create!({
  name: "Action",
  comment: "Genre cinématographique aux scènes spectaculaires, construit autour d'un conflit résolu de manière violente, généralement par la mort des ennemis du héros."
  })
Gender.create!({
  name: "Aventure",
  comment: "Genre cinématographique caractérisé par la présence d'un héros, véhiculant une idée générale de dépaysement."
  })
Gender.create!({
  name: "Science fiction",
  comment: "Genre cinématographique qui consiste à raconter des fictions dans un futur,  un passé, ou des univers fictifs, reposant sur des progrès scientifiques et techniques."
  })
Gender.create!({
  name: "Fantastique",
  comment: "Genre cinématographique qui fait appel au surnaturel, à l'horreur, à l'insolite ou aux monstres, qui se fonde sur des éléments irrationnels, ou irréalistes. "
  })
Gender.create!({
  name: "Comédie dramatique",
  comment: "Genre cinématographique qui utilise les caractéristiques de la comédie à des fins dramatiques, en tournant généralement en dérision des éléments sombres ou négatifs."
  })
Gender.create!({
  name: "Comédie policière",
  comment: "Genre cinématographique combinant la comédie et le film policier. Ce genre est caractérisé par le recours à des intrigues criminelles et un humour omniprésent."
  })
Gender.create!({
  name: "Thriller",
  comment: "Genre cinématographique fondé sur le suspense ou la tension narrative pour provoquer une excitation ou une appréhension jusqu'au dénouement de l'intrigue."
  })
Gender.create!({
  name: "Espionnage",
  comment: "Genre cinématographique lié à l'espionnage de fiction, réalisé dans un traitement réaliste ou comme base fantaisiste."
  })
Gender.create!({
  name: "Super-héros",
  comment: "Genre cinématographique mettant en scène les actions de super-héros, individus aux pouvoirs surhumains, dont ils se servent pour protéger la population."
  })
Gender.create!({
  name: "Biopic",
  comment: "Genre cinématographie qui raconte la vie d'une ou plusieurs personnes réelles, en opposition aux fictions."
  })
Gender.create!({
  name: "Fantasy",
  comment: " Genre cinématographique fondé sur l'imaginaire et le merveilleux de la culture anglo-saxonne."
  })
Gender.create!({
  name: "Péplum",
  comment: "Genre cinématographique de fiction historique dont l'action se déroule dans l'Antiquité."
  })
Gender.create!({
  name: "Historique",
  comment: "Genre cinématographique qui est fondé sur le principe de la fiction historique et qui met en scène des évènements historiques."
  })
Gender.create!({
  name: "Western",
  comment: "Genre cinématographique dont l'action se déroule généralement en Amérique du Nord lors de la conquête de l'Ouest dans les dernières décennies du XIXe siècle."
  })
Gender.create!({
  name: "Musical",
  comment: "Genre cinématographique qui contient de la musique, des chansons et/ou de la danse."
  })
Gender.create!({
  name: "Horreur",
  comment: "Genre cinématographique dont l'objectif est de créer un sentiment de peur, de répulsion ou d'angoisse chez le spectateur."
  })
Gender.create!({
  name: "Catastrophe",
  comment: "Genre cinématographique à suspense, dont l'intrigue met en scène une catastrophe naturelle ou technologique et les conséquences qui en découlent."
  })
Gender.create!({
  name: "Documentaire",
  comment: "Genre cinématographique qui se différencie de la fiction, par son caractère didactique ou informatif qui vise principalement à restituer les apparences de la réalité."
  })
Gender.create!({
  name: "Guerre",
  comment: "Genre cinématographique relatif au thème de la guerre, en s'attardant généralement sur un conflit armé qu'il soit naval, aérien ou terrestre."
  })
Gender.create!({
  name: "Animation",
  comment: "Genre cinématographique qui s'appuie sur des techniques donnant l'illusion du mouvement d'un être vivant ou d'un objet, supposé entreprendre une quelconque transformation."
  })
Gender.create!({
  name: "Thé\303\242tre",
  comment: "Le théâtre repose sur des dialogues entre personnages en communication directe. Il s'appuie sur les principes de vraisemblance, d'unité de temps, d'espace et d'action."
  })

puts "Deleting LanguageVersions..."
LanguageVersion.destroy_all
LanguageVersion.connection.execute('ALTER SEQUENCE language_versions_id_seq RESTART WITH 1')

puts "Creating language_versions..."
LanguageVersion.create!({short_name: "VF", long_name: "Version française"})
LanguageVersion.create!({short_name: "VO", long_name: "Version originale"})
LanguageVersion.create!({short_name: "VM", long_name: "Version multilingue"})
LanguageVersion.create!({short_name: "VOST", long_name: "Version originale sous-titrée"})
LanguageVersion.create!({short_name: "VMST", long_name: "Version multilingue sous-titrée"})

(function () {
  'use strict';

  var FREQ = [
    { label: 'Jamais', value: 0 },
    { label: 'Plusieurs jours', value: 1 },
    { label: 'Plus de la moitié des jours', value: 2 },
    { label: 'Presque tous les jours', value: 3 }
  ];

  var AGREE = [
    { label: 'Tout à fait d’accord', value: 3 },
    { label: 'D’accord', value: 2 },
    { label: 'Pas d’accord', value: 1 },
    { label: 'Pas du tout d’accord', value: 0 }
  ];

  var GREEN = { color: '#1E9E6A', bg: '#E6F6EF', ink: '#0E5F3F' };
  var TEAL = { color: '#0D7B6E', bg: '#E6F4F1', ink: '#06413A' };
  var GOLD = { color: '#C98A16', bg: '#FDF3E0', ink: '#8A5E10' };
  var ORANGE = { color: '#C2611F', bg: '#FBEDE2', ink: '#7E3D12' };
  var RED = { color: '#D64545', bg: '#FDECEA', ink: '#8E2C2C' };

  var SCALES = {
    phq9: {
      id: 'phq9',
      kicker: 'PHQ-9',
      title: 'Humeur et moral',
      max: 27,
      options: FREQ,
      context: 'Au cours des deux dernières semaines, à quelle fréquence avez-vous été gêné(e) par ce problème ?',
      source: 'Patient Health Questionnaire (PHQ-9), Kroenke, Spitzer & Williams, 2001. Échelle libre d’usage.',
      items: [
        'Peu d’intérêt ou peu de plaisir à faire les choses',
        'Vous sentir triste, déprimé(e) ou désespéré(e)',
        'Difficultés à vous endormir, à rester endormi(e), ou au contraire dormir trop',
        'Vous sentir fatigué(e) ou manquer d’énergie',
        'Avoir peu d’appétit, ou au contraire manger beaucoup trop',
        'Avoir une mauvaise opinion de vous-même, avoir le sentiment d’être nul(le) ou d’avoir déçu votre famille',
        'Avoir du mal à vous concentrer, par exemple pour lire ou suivre une conversation',
        'Bouger ou parler si lentement que les autres ont pu le remarquer — ou au contraire être si agité(e) que vous aviez du mal à tenir en place',
        'Penser qu’il vaudrait mieux mourir, ou envisager de vous faire du mal d’une manière ou d’une autre'
      ],
      bands: [
        {
          min: 0, max: 4, label: 'Aucun signe ou signes minimes', theme: GREEN,
          text: [
            'Sur les deux dernières semaines, vos réponses ne font pas apparaître de signe marqué d’humeur dépressive. C’est une bonne nouvelle, et elle mérite d’être dite.',
            'Cela n’annule pas ce que vous traversez par ailleurs. Un questionnaire mesure une période de quinze jours — il ne mesure pas une vie. Si quelque chose vous préoccupe malgré ce résultat, cette préoccupation est légitime.'
          ],
          cta: 'Refaire le point de temps en temps'
        },
        {
          min: 5, max: 9, label: 'Signes légers', theme: TEAL,
          text: [
            'Quelques signes sont présents, mais leur intensité reste faible. C’est très souvent le reflet d’une période chargée, d’une fatigue accumulée, d’un deuil récent ou d’un changement de vie.',
            'La bonne réaction à ce stade n’est pas l’inquiétude, c’est l’attention : refaites ce test dans deux semaines. Si le score monte, ou si ce que vous ressentez commence à gêner votre travail, votre sommeil ou vos relations, parlez-en à un professionnel.'
          ],
          cta: 'En parler avant que ça ne s’installe'
        },
        {
          min: 10, max: 14, label: 'Signes modérés', theme: GOLD,
          text: [
            'Vous avez atteint le seuil à partir duquel les cliniciens envisagent habituellement un accompagnement. Ce que vous ressentez a une intensité réelle et une durée — ce n’est pas « dans votre tête », et ce n’est pas un manque de volonté.',
            'Un premier entretien avec un psychologue permettrait de faire le tri entre ce qui relève d’une période difficile et ce qui demande un vrai suivi. C’est un rendez-vous, pas un engagement à vie.'
          ],
          cta: 'Prendre un premier rendez-vous'
        },
        {
          min: 15, max: 19, label: 'Signes modérément sévères', theme: ORANGE,
          text: [
            'Vos réponses décrivent une souffrance nette et installée sur les deux dernières semaines. À ce niveau, tenir le quotidien demande une énergie que la plupart des gens autour de vous n’imaginent pas.',
            'Une consultation avec un professionnel est vivement recommandée, et rapidement. Un épisode dépressif se soigne — et il se soigne d’autant mieux qu’on ne le laisse pas s’enraciner.'
          ],
          cta: 'Consulter un psychologue rapidement'
        },
        {
          min: 20, max: 27, label: 'Signes sévères', theme: RED,
          text: [
            'Vos réponses font apparaître une souffrance importante sur presque toutes les dimensions du questionnaire. Ce résultat mérite d’être pris au sérieux, aujourd’hui et non plus tard.',
            'Ne restez pas seul(e) avec ça. Parlez-en à un professionnel, et si vous le pouvez, à une personne de confiance de votre entourage dès aujourd’hui. Ce que vous vivez porte un nom, et il existe des prises en charge qui fonctionnent.'
          ],
          cta: 'Trouver un psychologue maintenant'
        }
      ]
    },

    gad7: {
      id: 'gad7',
      kicker: 'GAD-7',
      title: 'Anxiété et inquiétude',
      max: 21,
      options: FREQ,
      context: 'Au cours des deux dernières semaines, à quelle fréquence avez-vous été gêné(e) par ce problème ?',
      source: 'Generalized Anxiety Disorder scale (GAD-7), Spitzer, Kroenke, Williams & Löwe, 2006. Échelle libre d’usage.',
      items: [
        'Vous sentir nerveux(se), anxieux(se) ou très tendu(e)',
        'Être incapable d’arrêter de vous inquiéter ou de contrôler vos inquiétudes',
        'Vous inquiéter excessivement à propos de tout et de rien',
        'Avoir du mal à vous détendre',
        'Être si agité(e) qu’il est difficile de rester tranquille',
        'Devenir facilement contrarié(e) ou irritable',
        'Avoir peur que quelque chose d’épouvantable puisse arriver'
      ],
      bands: [
        {
          min: 0, max: 4, label: 'Anxiété minime', theme: GREEN,
          text: [
            'Vos réponses ne font pas apparaître de niveau d’anxiété problématique sur les deux dernières semaines.',
            'Une part d’inquiétude est normale et même utile : c’est ce qui nous fait préparer un examen ou regarder avant de traverser. Elle ne devient un sujet que lorsqu’elle tourne en boucle sans permettre d’agir.'
          ],
          cta: 'Garder un œil, sans s’alarmer'
        },
        {
          min: 5, max: 9, label: 'Anxiété légère', theme: TEAL,
          text: [
            'Une anxiété est présente, à un niveau qui reste supportable mais qui se remarque : difficulté à décrocher, tension de fond, sommeil qui s’allège.',
            'C’est le moment idéal pour agir, précisément parce que ce n’est pas encore lourd. Quelques séances suffisent souvent à désamorcer un mécanisme d’inquiétude avant qu’il ne s’installe durablement.'
          ],
          cta: 'Désamorcer avant que ça ne monte'
        },
        {
          min: 10, max: 14, label: 'Anxiété modérée', theme: GOLD,
          text: [
            'Vous êtes au-dessus du seuil habituellement retenu pour un trouble anxieux. Concrètement : l’inquiétude ne se déclenche plus seulement face à un problème réel, elle tourne d’elle-même.',
            'C’est l’un des motifs de consultation où l’accompagnement donne les résultats les plus rapides et les plus nets. Un professionnel pourra vous donner des outils concrets, pas seulement une écoute.'
          ],
          cta: 'Prendre rendez-vous'
        },
        {
          min: 15, max: 21, label: 'Anxiété sévère', theme: RED,
          text: [
            'Vos réponses décrivent une anxiété intense et quasi permanente. À ce niveau, elle consomme une énergie considérable et déborde généralement sur le sommeil, le corps, la concentration et les relations.',
            'Une consultation est vivement recommandée, sans attendre que ça passe tout seul. L’anxiété sévère répond bien à une prise en charge — l’attente, elle, ne fait que renforcer les boucles.'
          ],
          cta: 'Consulter rapidement'
        }
      ]
    },

    rses: {
      id: 'rses',
      kicker: 'Échelle de Rosenberg',
      title: 'Estime de soi',
      max: 30,
      options: AGREE,
      context: 'Indiquez à quel point vous êtes d’accord avec cette affirmation.',
      source: 'Rosenberg Self-Esteem Scale (RSES), Morris Rosenberg, 1965. Échelle libre d’usage à des fins éducatives et de recherche.',
      items: [
        { text: 'Je pense que je suis une personne de valeur, au moins autant que les autres.' },
        { text: 'Je pense que je possède un certain nombre de belles qualités.' },
        { text: 'Tout bien considéré, je suis porté(e) à me considérer comme un(e) raté(e).', reverse: true },
        { text: 'Je suis capable de faire les choses aussi bien que la majorité des gens.' },
        { text: 'Je sens peu de raisons d’être fier(ère) de moi.', reverse: true },
        { text: 'J’ai une attitude positive vis-à-vis de moi-même.' },
        { text: 'Dans l’ensemble, je suis satisfait(e) de moi.' },
        { text: 'J’aimerais avoir plus de respect pour moi-même.', reverse: true },
        { text: 'Parfois je me sens vraiment inutile.', reverse: true },
        { text: 'Il m’arrive de penser que je suis un(e) bon(ne) à rien.', reverse: true }
      ],
      bands: [
        {
          min: 0, max: 14, label: 'Estime de soi basse', theme: ORANGE,
          text: [
            'Le regard que vous portez sur vous-même est sévère — plus sévère, très probablement, que celui que vous porteriez sur quelqu’un d’autre dans la même situation.',
            'L’estime de soi n’est pas un trait de caractère gravé une fois pour toutes. Elle se construit, souvent à partir de ce qu’on nous a renvoyé très tôt, et elle se retravaille. C’est précisément l’un des terrains où un accompagnement psychologique change les choses en profondeur.'
          ],
          cta: 'En parler à un psychologue'
        },
        {
          min: 15, max: 25, label: 'Estime de soi dans la moyenne', theme: TEAL,
          text: [
            'Votre score se situe dans la fourchette la plus courante. Vous vous reconnaissez des qualités, tout en gardant des zones de doute — ce qui est la position la plus répandue, et la plus humaine.',
            'Si certaines affirmations vous ont accroché plus que d’autres, elles valent la peine d’être regardées de plus près. Ce sont souvent les points précis, pas le score global, qui portent l’information la plus utile.'
          ],
          cta: 'Creuser les points qui accrochent'
        },
        {
          min: 26, max: 30, label: 'Estime de soi élevée', theme: GREEN,
          text: [
            'Vous vous accordez de la valeur et vous vous reconnaissez des compétences. C’est une ressource solide, et un facteur de protection réel face aux périodes difficiles.',
            'Une estime de soi haute n’immunise pas contre l’anxiété ou la baisse de moral — ce sont des dimensions différentes. Si quelque chose vous pèse en ce moment, les deux autres questionnaires éclaireront mieux ce point.'
          ],
          cta: 'Explorer les autres questionnaires'
        }
      ]
    }
  };

  var hub = document.getElementById('hub');
  var runner = document.getElementById('runner');
  var resultSection = document.getElementById('result');
  var qFrame = document.getElementById('qFrame');
  var qCount = document.getElementById('qCount');
  var qProgress = document.getElementById('qProgress');
  var btnBack = document.getElementById('btnBack');
  var resultBody = document.getElementById('resultBody');

  var state = null;

  function itemText(item) {
    return typeof item === 'string' ? item : item.text;
  }

  function isReverse(item) {
    return typeof item === 'object' && item.reverse === true;
  }

  function bandFor(scale, score) {
    for (var i = 0; i < scale.bands.length; i++) {
      if (score >= scale.bands[i].min && score <= scale.bands[i].max) return scale.bands[i];
    }
    return scale.bands[scale.bands.length - 1];
  }

  function scoreOf(scale, answers) {
    var total = 0;
    for (var i = 0; i < scale.items.length; i++) {
      var raw = answers[i];
      if (raw === null || raw === undefined) continue;
      total += isReverse(scale.items[i]) ? (3 - raw) : raw;
    }
    return total;
  }

  function show(section) {
    [hub, runner, resultSection].forEach(function (s) {
      s.classList.toggle('is-hidden', s !== section);
    });
  }

  function start(scale) {
    state = { scale: scale, index: 0, answers: new Array(scale.items.length).fill(null) };
    show(runner);
    renderQuestion();
    window.scrollTo({ top: 0, behavior: 'auto' });
  }

  function renderQuestion() {
    var scale = state.scale;
    var i = state.index;
    var total = scale.items.length;

    qCount.textContent = 'Question ' + (i + 1) + ' sur ' + total;
    qProgress.style.width = ((i / total) * 100) + '%';
    btnBack.textContent = i === 0 ? '← Tous les tests' : '← Question précédente';

    var html = '<div class="fade-in">';
    html += '<div class="q-context">' + scale.kicker + ' · ' + scale.context + '</div>';
    html += '<div class="q-text">' + itemText(scale.items[i]) + '</div>';
    html += '<div class="choices">';
    scale.options.forEach(function (opt, k) {
      var picked = state.answers[i] === opt.value ? ' is-picked' : '';
      html += '<button type="button" class="choice' + picked + '" data-value="' + opt.value + '">' +
        '<span class="mark"></span><span>' + opt.label + '</span><kbd>' + (k + 1) + '</kbd></button>';
    });
    html += '</div></div>';

    qFrame.innerHTML = html;

    Array.prototype.forEach.call(qFrame.querySelectorAll('.choice'), function (btn) {
      btn.addEventListener('click', function () {
        answer(parseInt(btn.getAttribute('data-value'), 10));
      });
    });
  }

  function answer(value) {
    state.answers[state.index] = value;
    if (state.index < state.scale.items.length - 1) {
      state.index += 1;
      renderQuestion();
    } else {
      qProgress.style.width = '100%';
      renderResult();
    }
  }

  function goBack() {
    if (!state) return;
    if (state.index === 0) {
      state = null;
      location.hash = '';
      show(hub);
      window.scrollTo({ top: 0, behavior: 'auto' });
      return;
    }
    state.index -= 1;
    renderQuestion();
  }

  function gaugeHtml(scale, score) {
    var span = scale.max + 1;
    var track = '';
    scale.bands.forEach(function (b) {
      var w = ((b.max - b.min + 1) / span) * 100;
      track += '<i style="width:' + w + '%;background:' + b.theme.color + '"></i>';
    });
    var pos = ((score + 0.5) / span) * 100;
    return '<div class="gauge">' +
      '<div class="gauge-track">' + track + '</div>' +
      '<div class="gauge-cursor"><b style="left:' + pos + '%"></b></div>' +
      '<div class="gauge-labels"><span>0</span><span>' + scale.max + '</span></div>' +
      '</div>';
  }

  function crisisHtml() {
    return '<div class="crisis">' +
      '<h4>Un point qu’on ne peut pas laisser passer</h4>' +
      '<p>Vous avez indiqué avoir eu des pensées de mort ou de vous faire du mal. Quelle qu’en soit la fréquence, ce n’est pas une case parmi d’autres : c’est une raison suffisante, à elle seule, d’en parler à quelqu’un dès aujourd’hui.</p>' +
      '<p style="margin-top:12px">Si le danger est immédiat, appelez le <strong>SAMU au 1515</strong> ou les <strong>sapeurs-pompiers au 18</strong>. Vous pouvez aussi joindre directement l’<strong>hôpital psychiatrique de Thiaroye au 33 834 08 81</strong> ou le <strong>service de psychiatrie du CHNU Fann au 33 869 18 18</strong>. Et si vous le pouvez, dites-le à une personne de confiance autour de vous, maintenant.</p>' +
      '<div class="emergency-nums">' +
      '<a href="tel:1515">Appeler le 1515</a>' +
      '<a href="tel:18">Appeler le 18</a>' +
      '<a href="tel:+221338340881">Thiaroye · 33 834 08 81</a>' +
      '</div></div>';
  }

  function renderResult() {
    var scale = state.scale;
    var score = scoreOf(scale, state.answers);
    var band = bandFor(scale, score);
    var crisis = scale.id === 'phq9' && state.answers[8] > 0;

    var html = '<div class="fade-in">';
    html += '<div class="eyebrow">' + scale.kicker + ' · votre résultat</div>';
    html += '<div class="score-block">';
    html += '<div class="score-head">' +
      '<span class="score-num" style="color:' + band.theme.color + '">' + score + '</span>' +
      '<span class="score-max">sur ' + scale.max + '</span>' +
      '<span class="score-band" style="background:' + band.theme.bg + ';color:' + band.theme.ink + '">' + band.label + '</span>' +
      '</div>';
    html += gaugeHtml(scale, score);
    html += '</div>';

    html += '<h2>Ce que cela veut dire</h2>';
    band.text.forEach(function (p) { html += '<p>' + p + '</p>'; });

    if (crisis) html += crisisHtml();

    html += '<div class="limits">' +
      '<h4>Ce que ce score ne dit pas</h4>' +
      '<p>Ce questionnaire ne connaît ni votre histoire, ni votre contexte, ni ce que vous avez traversé cette semaine. Il ne pose aucun diagnostic et ne remplace pas l’évaluation d’un professionnel, qui seul peut faire la différence entre une réaction normale à une situation difficile et un trouble constitué. Prenez ce chiffre pour ce qu’il est : un point de départ pour en parler.</p>' +
      '</div>';

    html += '<div class="next-step">' +
      '<h3>' + band.cta + '</h3>' +
      '<p>Sur PsyConnect, vous choisissez un psychologue dont le diplôme a été vérifié, en vidéo, en audio ou au cabinet — et vous pouvez rester anonyme jusqu’à ce que vous décidiez du contraire.</p>' +
      '<div class="row">' +
      '<a class="btn btn--gold" href="index.html#application">Découvrir PsyConnect</a>' +
      '<a class="btn btn--ghost" style="color:#fff;border-color:rgba(255,255,255,.4)" href="index.html#faq">Comment ça marche</a>' +
      '</div></div>';

    html += '<div class="result-actions">' +
      '<button class="btn btn--ghost" type="button" id="btnRetry">Refaire ce test</button>' +
      '<button class="btn btn--ghost" type="button" id="btnHub">Voir les autres tests</button>' +
      '</div>';

    html += '<p style="margin-top:26px;font-size:13.5px;color:var(--muted)">' + scale.source + ' Traduction française à usage informatif.</p>';
    html += '</div>';

    resultBody.innerHTML = html;
    show(resultSection);
    window.scrollTo({ top: 0, behavior: 'auto' });

    document.getElementById('btnRetry').addEventListener('click', function () { start(scale); });
    document.getElementById('btnHub').addEventListener('click', function () {
      state = null;
      location.hash = '';
      show(hub);
      window.scrollTo({ top: 0, behavior: 'auto' });
    });
  }

  function route() {
    var id = location.hash.replace('#', '');
    if (SCALES[id]) {
      start(SCALES[id]);
    } else {
      state = null;
      show(hub);
    }
  }

  btnBack.addEventListener('click', goBack);

  document.addEventListener('keydown', function (e) {
    if (!state || runner.classList.contains('is-hidden')) return;
    var n = parseInt(e.key, 10);
    if (n >= 1 && n <= state.scale.options.length) {
      e.preventDefault();
      answer(state.scale.options[n - 1].value);
    } else if (e.key === 'Backspace' || e.key === 'ArrowLeft') {
      e.preventDefault();
      goBack();
    }
  });

  window.addEventListener('hashchange', route);
  route();
})();

#import "preamble.typ":*

= Kate-Zaverucha-Goldberg (KZG) commitments <kzg>

== Pitch: KZG lets you commit a polynomial and reveal individual values

The goal of the KZG commitment schemes is to have the following API:

- Peggy has a secret polynomial $P(X) in FF_q [X]$.
- Peggy sends a short "commitment" to the polynomial (like a hash).
- This commitment should have the additional property that
  Peggy should be able to "open" the commitment at any $z in FF_q$.
  Specifically:

  - Victor has an input $z in FF_q$ and wants to know $P(z)$.
  - Peggy knows $P$ so she can compute $P(z)$;
    she sends the resulting number $y = P(z)$ to Victor.
  - Peggy can then send a short "proof" convincing Victor that $y$ is the
    correct value, without having to reveal $P$.

The KZG commitment scheme is amazingly efficient because both the commitment
and proof lengths are a single point on $E$, encodable in 256 bits.

== Elliptic curve setup done once

The good news is that this can be done just once, period.
After that, anyone in the world can use the published data to run this protocol.

For concreteness, $E$ will be the BN256 curve and $g$ a fixed generator.

=== The notation $[n]$

We retain the notation $[n] := n dot g in E$ defined in @armor.

=== Trusted calculation

To set up the KZG commitment scheme,
a trusted party needs to pick a secret scalar $s in FF_q$ and publishes
$ [s^0], [s^1], ..., [s^M] $
for some large $M$, the maximum degree of a polynomial the scheme needs to support.
This means anyone can evaluate $[P(s)]$ for any given polynomial $P$ of degree up to $M$.
(For example, $[s^2+8s+6] = [s^2] + 8[s] + 6[1]$.)
Meanwhile, the secret scalar $s$ is never revealed to anyone.

This only needs to be done by a trusted party once for the curve $E$.
Then anyone in the world can use the resulting sequence for KZG commitments.

#remark[
  The trusted party has to delete $s$ after the calculation.
  If anybody knows the value of $s$, the protocol will be insecure.
  The trusted party will only publish $[s^0] = [1], [s^1], ..., [s^M]$.
  Given these published values, it is (probably) extremely hard to recover $s$ --
  this is a case of the discrete logarithm problem.

  You can make the protocol somewhat more secure by involving several different trusted parties.
  The first party chooses a random $s_1$, computes $[s_1^0], ..., [s_1^M]$, and then discards s_1.
  The second party chooses $s_2$ and computes
  $[(s_1 s_2)^0], ..., [(s_1 s_2)^M]$.
  And so forth.
  In the end, the value $s$ will be the product of the secrets $s_i$
  chosen by the $i$ parties... so the only way they can break secrecy
  is if all the "trusted parties" collaborate.
]

== The KZG commitment scheme

Peggy has a polynomial $P(X) in FF_p [X]$.
To commit to it:

#algorithm("Creating a KZG commitment")[
  1. Peggy computes and publishes $[P(s)]$.
]
This computation is possible as $[s^i]$ are globally known.

Now consider an input $z in FF_p$; Victor wants to know the value of $P(z)$.
If Peggy wishes to convince Victor that $P(z) = y$, then:

#algorithm("Opening a KZG commitment")[
  1. Peggy does polynomial division to compute $Q(X) in FF_q [X]$ such that
    $ P(X)-y = (X-z) Q(X). $
  2. Peggy computes and sends Victor $[Q(s)]$,
    which again she can compute from the globally known $[s^i]$.
  3. Victor verifies by checking
    #eqn[
      $ pair([Q(s)], [s]-[z]) = pair([P(s)]-[y], [1]) $
      <kzg-verify>
    ]
    and accepts if and only if @kzg-verify is true.
]

If Peggy is truthful, then @kzg-verify will certainly check out.

If $y != P(z)$, then Peggy can't do the polynomial long division described above.
So to cheat Victor, she needs to otherwise find an element
$ 1/(s-x) ([P(s)]-[y]) in E. $
Since $s$ is a secret nobody knows, there isn't any known way to do this.

== Multi-openings

To reveal $P$ at a single value $z$, we did polynomial division
to divide $P(X)$ by $X-z$.
But there's no reason we have to restrict ourselves to linear polynomials;
this would work equally well with higher-degree polynomials,
while still using only a single 256-bit for the proof.

For example, suppose Peggy wanted to prove that
$P(1) = 100$, $P(2) = 400$, ..., $P(9) = 8100$.
Then she could do polynomial long division to get a polynomial $Q$
of degree $deg(P) - 9$ such that
$ P(X) - 100X^2 = (T-1)(T-2) ... (T-9) dot Q(T). $
Then Peggy sends $[Q(s)]$ as her proof, and the verification equation is that
$ pair([Q(s)], [(s-1)(s-2) ... (s-9)]) = pair([P(s)] - 100[s^2], [1]). $

The full generality just replaces the $100T^2$ with the polynomial
obtained from #link("https://w.wiki/8Yin", "Lagrange interpolation")
(there is a unique such polynomial $f$ of degree $n-1$).
To spell this out, suppose Peggy wishes to prove to Victor that
$P(z_i) = y_i$ for $1 <= i <= n$.

#algorithm[Opening a KZG commitment at $n$ values][
  1. By Lagrange interpolation, both parties agree on a polynomial $f(X)$
    such that $f(z_i) = y_i$.
  2. Peggy does polynomial long division to get $Q(X)$ such that
    $ P(X) - f(X) = (X-z_1)(X-z_2) ... (X-z_n) dot Q(X). $
  3. Peggy sends the single element $[Q(s)]$ as her proof.
  4. Victor verifies
    $ pair([Q(s)], [(s-z_1)(s-z_2) ... (s-z_n)]) = pair([P(s)] - [f(s)], [1]). $
]

So one can even open the polynomial $P$ at $1000$ points with a single 256-bit proof.
The verification runtime is a single pairing plus however long
it takes to compute the Lagrange interpolation $f$.

